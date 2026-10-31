import Foundation

public protocol FileScanner: Sendable {
    var module: ModuleID { get }
    func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult
}

public struct CleanReport: Hashable {
    public let removedCount: Int
    public let freedBytes: Int64
    public let failedItems: [URL]
    /// Original path -> Trash path for each item moved to the Trash (history / restore).
    public var trashed: [TrashRecord] = []
    /// How many of `removedCount` were removed for good (no Trash, no restore).
    public var permanentCount: Int = 0
    /// Bytes of those permanent removals.
    public var permanentBytes: Int64 = 0

    public init(removedCount: Int, freedBytes: Int64, failedItems: [URL], trashed: [TrashRecord] = [],
                permanentCount: Int = 0, permanentBytes: Int64 = 0) {
        self.removedCount = removedCount
        self.freedBytes = freedBytes
        self.failedItems = failedItems
        self.trashed = trashed
        self.permanentCount = permanentCount
        self.permanentBytes = permanentBytes
    }

    /// Items moved to the Trash (restorable).
    public var trashedCount: Int { max(0, removedCount - permanentCount) }
    /// Bytes moved to the Trash: they only free disk space once the Trash is emptied.
    public var trashedBytes: Int64 { max(0, freedBytes - permanentBytes) }

    public static let empty = CleanReport(removedCount: 0, freedBytes: 0, failedItems: [])

    public func merged(with o: CleanReport) -> CleanReport {
        CleanReport(removedCount: removedCount + o.removedCount,
                    freedBytes: freedBytes + o.freedBytes,
                    failedItems: failedItems + o.failedItems,
                    trashed: trashed + o.trashed,
                    permanentCount: permanentCount + o.permanentCount,
                    permanentBytes: permanentBytes + o.permanentBytes)
    }
}

public enum Cleaner {
    /// The cleaning entry point. Each item is handled according to its kind's
    /// `deletionPolicy`:
    /// - regenerable data (caches, logs, temp files) and the Trash itself are
    ///   removed **permanently** — they come back by themselves, and moving
    ///   them to the Trash would not free any disk space;
    /// - personal files (large / old / duplicates / photos), browser data and
    ///   apps go to the **Trash** (reversible);
    /// - everything else (findings, tasks, updates…) is ignored.
    public static func clean(items: [ScanItem], dryRun: Bool = false) -> CleanReport {
        let permanent = items.filter { $0.kind.deletionPolicy == .permanent }
        let trashable = items.filter { $0.kind.deletionPolicy == .trash }
        if dryRun {
            let p = permanent.reduce(into: Int64(0)) { $0 += $1.size }
            let t = trashable.reduce(into: Int64(0)) { $0 += $1.size }
            return CleanReport(removedCount: permanent.count + trashable.count, freedBytes: p + t,
                               failedItems: [], permanentCount: permanent.count, permanentBytes: p)
        }
        return delete(items: permanent).merged(with: trash(items: trashable))
    }

    /// Move items to ~/.Trash (reversible), whatever their kind.
    public static func trash(items: [ScanItem]) -> CleanReport {
        var freed: Int64 = 0
        var removed = 0
        var failed: [URL] = []
        var trashed: [TrashRecord] = []
        let fm = FileManager.default

        for item in items {
            guard isSafeToRemove(item.url) else { failed.append(item.url); continue }
            do {
                var resultingURL: NSURL? = nil
                try fm.trashItem(at: item.url, resultingItemURL: &resultingURL)
                if let t = resultingURL as URL? {
                    trashed.append(TrashRecord(originalPath: item.url.path, trashPath: t.path))
                }
                freed += item.size
                removed += 1
            } catch {
                failed.append(item.url)
            }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed, trashed: trashed)
    }

    /// Permanent removal (no Trash). Used for regenerable data and by the
    /// Uninstaller so a removed .app never lingers in the Trash where other
    /// cleaners detect it. Irreversible by design.
    ///
    /// A folder that cannot be removed entirely (a protected file inside) still
    /// counts for what really went away, so the report never over-states.
    public static func delete(items: [ScanItem]) -> CleanReport {
        var freed: Int64 = 0
        var removed = 0
        var failed: [URL] = []
        let fm = FileManager.default
        for item in items {
            guard isSafeToRemove(item.url) else { failed.append(item.url); continue }
            do {
                try fm.removeItem(at: item.url)
                freed += item.size
                removed += 1
            } catch {
                if fm.fileExists(atPath: item.url.path) {
                    let left = remainingSize(of: item.url)
                    freed += max(0, item.size - left)
                    failed.append(item.url)
                } else {
                    freed += item.size
                    removed += 1
                }
            }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed,
                           permanentCount: removed, permanentBytes: freed)
    }

    /// The failed items as they are now on disk (size = what is left), to retry
    /// them with admin rights without counting twice what was already freed.
    public static func residual(of items: [ScanItem], failed: [URL]) -> [ScanItem] {
        let set = Set(failed)
        return items.filter { set.contains($0.url) }.compactMap { item in
            guard FileManager.default.fileExists(atPath: item.url.path) else { return nil }
            return item.resized(min(item.size, remainingSize(of: item.url)))
        }
    }

    static func remainingSize(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        return isDir.boolValue ? FS.directorySize(url) : FS.size(of: url)
    }

    /// Hard guard against catastrophic paths: never remove a root, the home
    /// folder, or one of the well-known container folders themselves (only
    /// what is inside them).
    public static func isSafeToRemove(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        guard url.isFileURL, !path.isEmpty, path != "/" else { return false }
        if url.pathComponents.contains("..") { return false }
        let home = FS.home.standardizedFileURL.path
        let protected: Set<String> = [
            home, "/Users", "/Library", "/System", "/Applications", "/private", "/usr", "/bin",
            "/sbin", "/var", "/etc", "/opt", "/Volumes", "/tmp",
            home + "/Library", home + "/Library/Caches", home + "/Library/Logs",
            home + "/Library/Application Support", home + "/Library/Preferences",
            home + "/Documents", home + "/Downloads", home + "/Desktop", home + "/Movies",
            home + "/Pictures", home + "/Music", home + "/.Trash",
            "/Library/Caches", "/Library/Logs", "/private/var/folders",
        ]
        if protected.contains(path) { return false }
        return url.pathComponents.count >= 3
    }

    /// Admin fallback for permanent removal of root-owned items (`rm -rf` via a
    /// single native password prompt).
    public static func deleteWithAdmin(items: [ScanItem]) -> CleanReport {
        let items = items.filter { isSafeToRemove($0.url) }
        guard !items.isEmpty else { return CleanReport(removedCount: 0, freedBytes: 0, failedItems: []) }
        let cmds = items.map { "/bin/rm -rf \(singleQuoted($0.url.path))" }
        runAdmin(cmds.joined(separator: "; "))

        let fm = FileManager.default
        var freed: Int64 = 0, removed = 0, failed: [URL] = []
        for item in items {
            if fm.fileExists(atPath: item.url.path) { failed.append(item.url) }
            else { freed += item.size; removed += 1 }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed,
                           permanentCount: removed, permanentBytes: freed)
    }

    /// Fallback for items `trashItem` can't move (root-owned bundles like App
    /// Store apps): move them into ~/.Trash with a single admin-authenticated
    /// shell call (one native password prompt for the whole batch). Still safe
    /// — items land in the Trash, not `rm`'d — and restorable.
    public static func trashWithAdmin(items: [ScanItem]) -> CleanReport {
        let items = items.filter { isSafeToRemove($0.url) }
        guard !items.isEmpty else { return CleanReport(removedCount: 0, freedBytes: 0, failedItems: []) }
        let fm = FileManager.default
        let trashDir = NSHomeDirectory() + "/.Trash"

        let cmds = items.map { item -> String in
            let dest = trashDir + "/" + item.url.lastPathComponent
            return "/bin/mv -f \(singleQuoted(item.url.path)) \(singleQuoted(dest))"
        }
        runAdmin(cmds.joined(separator: "; "))

        // Whatever no longer exists at its source was moved successfully.
        var freed: Int64 = 0
        var removed = 0
        var failed: [URL] = []
        var trashed: [TrashRecord] = []
        for item in items {
            if fm.fileExists(atPath: item.url.path) {
                failed.append(item.url)
            } else {
                freed += item.size
                removed += 1
                trashed.append(TrashRecord(originalPath: item.url.path,
                                           trashPath: trashDir + "/" + item.url.lastPathComponent))
            }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed, trashed: trashed)
    }

    /// Retry with one admin prompt what `clean` could not remove (root-owned
    /// files): regenerable data is deleted for good, personal files are moved
    /// to the Trash, exactly like the unprivileged path. `failed` are the URLs
    /// reported by the first pass; only what is still on disk is retried.
    public static func cleanWithAdmin(items: [ScanItem], failed: [URL], forcePermanent: Bool = false) -> CleanReport {
        let left = residual(of: items, failed: failed).filter { isSafeToRemove($0.url) }
        let permanent = left.filter { forcePermanent ? $0.kind.deletionPolicy != .none : $0.kind.deletionPolicy == .permanent }
        let trashable = forcePermanent ? [] : left.filter { $0.kind.deletionPolicy == .trash }
        var report = CleanReport.empty
        if !permanent.isEmpty { report = report.merged(with: deleteWithAdmin(items: permanent)) }
        if !trashable.isEmpty { report = report.merged(with: trashWithAdmin(items: trashable)) }
        return report
    }

    /// Cleans `items` by policy and, when `adminFallback` is set, retries what
    /// failed (root-owned files) with a single admin prompt. With
    /// `forcePermanent` every cleanable item is deleted for good (Uninstaller).
    /// The returned report is the merged outcome of both passes.
    public static func clean(items: [ScanItem], forcePermanent: Bool, adminFallback: Bool) -> CleanReport {
        let cleanable = items.filter { $0.kind.deletionPolicy != .none }
        let first = forcePermanent ? delete(items: cleanable) : clean(items: cleanable)
        guard adminFallback, !first.failedItems.isEmpty else { return first }
        let retried = Set(residual(of: cleanable, failed: first.failedItems)
            .filter { isSafeToRemove($0.url) }.map(\.url))
        guard !retried.isEmpty else { return first }
        let admin = cleanWithAdmin(items: cleanable, failed: first.failedItems, forcePermanent: forcePermanent)
        let stillFailed = first.failedItems.filter { !retried.contains($0) } + admin.failedItems
        return CleanReport(removedCount: first.removedCount + admin.removedCount,
                           freedBytes: first.freedBytes + admin.freedBytes,
                           failedItems: stillFailed,
                           trashed: first.trashed + admin.trashed,
                           permanentCount: first.permanentCount + admin.permanentCount,
                           permanentBytes: first.permanentBytes + admin.permanentBytes)
    }

    /// Empties the Trash for good (the same operation as "Vider la corbeille").
    /// Returns `nil` when the Trash cannot be listed (no Full Disk Access): the
    /// caller then falls back on Finder.
    public static func emptyTrash(at trash: URL = FS.home.appendingPathComponent(".Trash")) -> CleanReport? {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: trash, includingPropertiesForKeys: nil, options: []) else { return nil }
        let items = children.map { url -> ScanItem in
            ScanItem(url: url, size: remainingSize(of: url), kind: .trash, group: "Trash")
        }
        return delete(items: items)
    }

    /// POSIX single-quote a path, escaping embedded single quotes.
    private static func singleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Run a shell command as admin via one native password prompt.
    private static func runAdmin(_ shell: String) {
        let esc = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(esc)\" with administrator privileges"
        _ = Shell.run("/usr/bin/osascript", ["-e", script], timeout: 300)
    }
}
