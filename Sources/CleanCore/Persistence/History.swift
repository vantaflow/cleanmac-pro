import Foundation

/// One file moved to the Trash: where it was, where it went.
public struct TrashRecord: Codable, Hashable, Sendable {
    public let originalPath: String
    public let trashPath: String
    public init(originalPath: String, trashPath: String) {
        self.originalPath = originalPath
        self.trashPath = trashPath
    }
}

public struct HistoryEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let module: String
    public let itemCount: Int
    public let freedBytes: Int64
    public let records: [TrashRecord]

    public init(id: UUID = UUID(), date: Date = Date(), module: String,
                itemCount: Int, freedBytes: Int64, records: [TrashRecord]) {
        self.id = id
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))  // ISO-8601 JSON keeps whole seconds
        self.module = module
        self.itemCount = itemCount
        self.freedBytes = freedBytes
        self.records = records
    }
}

public struct RestoreOutcome: Equatable, Sendable {
    public var restored: [String] = []
    public var missingFromTrash: [String] = []   // already emptied / moved away
    public var destinationTaken: [String] = []   // something else lives at the original path
    public var failed: [String] = []
    public init() {}

    /// Short French message for the UI.
    public var message: String {
        var parts: [String] = []
        if !restored.isEmpty { parts.append("\(restored.count) élément(s) restauré(s)") }
        if !missingFromTrash.isEmpty { parts.append("\(missingFromTrash.count) introuvable(s) dans la Corbeille (déjà vidée ?)") }
        if !destinationTaken.isEmpty { parts.append("\(destinationTaken.count) non restauré(s) : l'emplacement d'origine est déjà occupé") }
        if !failed.isEmpty { parts.append("\(failed.count) échec(s)") }
        return parts.isEmpty ? "Rien à restaurer" : parts.joined(separator: " · ")
    }
}

public struct CleanHistory: Codable, Equatable, Sendable {
    public static let maxEntries = 200
    /// Newest first.
    public private(set) var entries: [HistoryEntry]

    public init(entries: [HistoryEntry] = []) { self.entries = entries }

    public var totalFreedBytes: Int64 { entries.reduce(0) { $0 + $1.freedBytes } }

    public mutating func record(_ entry: HistoryEntry, limit: Int = CleanHistory.maxEntries) {
        entries.insert(entry, at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
    }

    /// Records a Trash cleanup from a `CleanReport`; no-op if nothing was trashed.
    @discardableResult
    public mutating func record(module: String, report: CleanReport, date: Date = Date()) -> HistoryEntry? {
        guard !report.trashed.isEmpty else { return nil }
        let e = HistoryEntry(date: date, module: module, itemCount: report.removedCount,
                             freedBytes: report.freedBytes, records: report.trashed)
        record(e)
        return e
    }

    public mutating func remove(id: UUID) { entries.removeAll { $0.id == id } }

    /// Moves files back from the Trash to their original location when they
    /// are still in the Trash and the destination is free.
    public static func restore(_ entry: HistoryEntry) -> RestoreOutcome {
        let fm = FileManager.default
        var out = RestoreOutcome()
        for r in entry.records {
            guard fm.fileExists(atPath: r.trashPath) else { out.missingFromTrash.append(r.originalPath); continue }
            if fm.fileExists(atPath: r.originalPath) { out.destinationTaken.append(r.originalPath); continue }
            do {
                let dest = URL(fileURLWithPath: r.originalPath)
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(atPath: r.trashPath, toPath: r.originalPath)
                out.restored.append(r.originalPath)
            } catch {
                out.failed.append(r.originalPath)
            }
        }
        return out
    }

    // MARK: Persistence

    public static func fileURL(in dir: URL = AppSupport.defaultDirectory) -> URL {
        dir.appendingPathComponent("history.json")
    }

    public static func load(from dir: URL = AppSupport.defaultDirectory) -> CleanHistory {
        AppSupport.load(CleanHistory.self, from: fileURL(in: dir)) ?? CleanHistory()
    }

    public func save(to dir: URL = AppSupport.defaultDirectory) throws {
        try AppSupport.save(self, to: Self.fileURL(in: dir))
    }
}
