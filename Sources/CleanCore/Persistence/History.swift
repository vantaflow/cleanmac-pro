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
    /// Only what went to the Trash: the sole part that can be restored.
    public let records: [TrashRecord]
    /// Removed for good (caches, logs, temp files, emptied Trash): no restore.
    public let permanentCount: Int
    public let permanentBytes: Int64

    /// A "Restaurer" button only makes sense when something sits in the Trash.
    public var canRestore: Bool { !records.isEmpty }

    public init(id: UUID = UUID(), date: Date = Date(), module: String,
                itemCount: Int, freedBytes: Int64, records: [TrashRecord],
                permanentCount: Int = 0, permanentBytes: Int64 = 0) {
        self.id = id
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))  // ISO-8601 JSON keeps whole seconds
        self.module = module
        self.itemCount = itemCount
        self.freedBytes = freedBytes
        self.records = records
        self.permanentCount = permanentCount
        self.permanentBytes = permanentBytes
    }

    // Entries written before permanent deletions existed have no such fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        module = try c.decode(String.self, forKey: .module)
        itemCount = try c.decode(Int.self, forKey: .itemCount)
        freedBytes = try c.decode(Int64.self, forKey: .freedBytes)
        records = try c.decode([TrashRecord].self, forKey: .records)
        permanentCount = try c.decodeIfPresent(Int.self, forKey: .permanentCount) ?? 0
        permanentBytes = try c.decodeIfPresent(Int64.self, forKey: .permanentBytes) ?? 0
    }
}

public struct RestoreOutcome: Equatable, Sendable {
    public var restored: [String] = []
    public var missingFromTrash: [String] = []   // already emptied / moved away
    public var destinationTaken: [String] = []   // something else lives at the original path
    public var failed: [String] = []
    /// Items of the entry that were deleted for good: nothing to restore.
    public var permanentlyDeleted: Int = 0
    public init() {}

    /// Short French message for the UI.
    public var message: String {
        var parts: [String] = []
        if !restored.isEmpty { parts.append(L("\(restored.count) élément(s) restauré(s)")) }
        if !missingFromTrash.isEmpty { parts.append(L("\(missingFromTrash.count) introuvable(s) dans la Corbeille (déjà vidée ?)")) }
        if !destinationTaken.isEmpty { parts.append(L("\(destinationTaken.count) non restauré(s) : l'emplacement d'origine est déjà occupé")) }
        if !failed.isEmpty { parts.append(L("\(failed.count) échec(s)")) }
        if parts.isEmpty && permanentlyDeleted > 0 {
            return L("\(Int(permanentlyDeleted)) élément(s) supprimé(s) définitivement : rien à restaurer")
        }
        return parts.isEmpty ? L("Rien à restaurer") : parts.joined(separator: " · ")
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

    /// Records a cleanup from a `CleanReport` (Trash moves and permanent
    /// deletions); no-op if nothing was removed.
    @discardableResult
    public mutating func record(module: String, report: CleanReport, date: Date = Date()) -> HistoryEntry? {
        guard report.removedCount > 0 else { return nil }
        let e = HistoryEntry(date: date, module: module, itemCount: report.removedCount,
                             freedBytes: report.freedBytes, records: report.trashed,
                             permanentCount: report.permanentCount, permanentBytes: report.permanentBytes)
        record(e)
        return e
    }

    public mutating func remove(id: UUID) { entries.removeAll { $0.id == id } }

    /// Moves files back from the Trash to their original location when they
    /// are still in the Trash and the destination is free.
    public static func restore(_ entry: HistoryEntry) -> RestoreOutcome {
        let fm = FileManager.default
        var out = RestoreOutcome()
        out.permanentlyDeleted = entry.permanentCount
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

public extension CleanHistory {
    /// Records a permanent deletion (no Trash records, nothing to restore).
    @discardableResult
    mutating func recordPermanent(module: String, report: CleanReport, date: Date = Date()) -> HistoryEntry? {
        guard report.removedCount > 0 else { return nil }
        let e = HistoryEntry(date: date, module: module, itemCount: report.removedCount,
                             freedBytes: report.freedBytes, records: [])
        record(e)
        return e
    }
}
