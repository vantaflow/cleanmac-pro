import Foundation

/// Free space of a volume at one instant.
public struct DiskSnapshot: Equatable, Sendable {
    public let freeBytes: Int64
    public let totalBytes: Int64
    public let date: Date

    public init(freeBytes: Int64, totalBytes: Int64, date: Date = Date()) {
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
        self.date = date
    }

    public var usedBytes: Int64 { max(0, totalBytes - freeBytes) }
    public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
}

public enum DiskSpace {
    /// Free space as the volume reports it *right now* (`volumeAvailableCapacity`,
    /// i.e. really unallocated blocks). We deliberately do not use the
    /// "important usage" figure: it adds purgeable space and would move on its
    /// own, hiding whether a cleanup actually freed anything.
    public static func snapshot(at url: URL = URL(fileURLWithPath: NSHomeDirectory())) -> DiskSnapshot? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeTotalCapacityKey]
        guard let v = try? url.resourceValues(forKeys: keys),
              let free = v.volumeAvailableCapacity, let total = v.volumeTotalCapacity else { return nil }
        return DiskSnapshot(freeBytes: Int64(free), totalBytes: Int64(total))
    }

    /// Name of the volume holding `url` ("Macintosh HD").
    public static func volumeName(at url: URL = URL(fileURLWithPath: NSHomeDirectory())) -> String {
        (try? url.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? "Macintosh HD"
    }
}

/// Before / after measurement of a cleanup: what the volume really gained
/// versus the sum of item sizes that the cleaner reports.
public struct SpaceMeasure: Equatable, Sendable {
    public let before: DiskSnapshot?
    public let after: DiskSnapshot?
    /// Sum of the sizes of what was removed (what the cleaner claims).
    public let reportedBytes: Int64
    /// Of which went to the Trash (frees nothing until the Trash is emptied).
    public let trashedBytes: Int64

    public init(before: DiskSnapshot?, after: DiskSnapshot?, reportedBytes: Int64, trashedBytes: Int64 = 0) {
        self.before = before
        self.after = after
        self.reportedBytes = reportedBytes
        self.trashedBytes = trashedBytes
    }

    /// Signed change of the volume's free space (can be slightly negative: other
    /// processes write while we clean). `nil` when the volume could not be read.
    public var measuredDelta: Int64? {
        guard let b = before, let a = after else { return nil }
        return a.freeBytes - b.freeBytes
    }

    /// The honest figure to show: measured gain, never negative. Falls back on
    /// the permanent part of the reported sizes when the volume is unreadable.
    public var freedBytes: Int64 {
        if let d = measuredDelta { return max(0, d) }
        return max(0, reportedBytes - trashedBytes)
    }

    /// True when the volume gained clearly less than what was removed (APFS
    /// snapshots, clones or files still open elsewhere keep blocks allocated).
    public var gainedLessThanReported: Bool {
        guard let d = measuredDelta else { return false }
        let expected = reportedBytes - trashedBytes
        return expected > 50_000_000 && d < expected / 2
    }
}
