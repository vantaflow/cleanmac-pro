import Foundation

/// Caches, logs, temporary files and the Trash.
///
/// Results are **grouped per top-level folder** (one row per app cache folder,
/// e.g. `~/Library/Caches/com.spotify.client`) instead of one row per file: a
/// real Mac has tens of thousands of cache files, which made the list
/// unreadable. This stays consistent with cleaning because everything this
/// scanner reports is regenerable and is removed as a whole folder
/// (`Cleaner.delete`, with the admin fallback for root-owned ones); a folder that
/// cannot be removed completely is still credited for what really went away.
/// Loose files at the top level of a root stay individual rows.
public struct CleanupScanner: FileScanner {
    public let module: ModuleID = .cleanup
    public var rootOverrides: [URL]?  // for tests

    public init(rootOverrides: [URL]? = nil) {
        self.rootOverrides = rootOverrides
    }

    struct Target {
        let url: URL
        let group: String
        let kind: ItemKind
        /// Entries modified more recently than this are left alone (apps may still use them).
        var minAge: TimeInterval = 0
    }

    /// The user's `$TMPDIR` (T) and Darwin cache (C) folders. We deliberately do
    /// not walk all of `/private/var/folders`: it also holds other users' data
    /// and live SQLite `-shm` / `-wal` files that apps are using.
    static func userTempFolders() -> [URL] {
        var urls = [URL(fileURLWithPath: NSTemporaryDirectory())]
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        if confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, buf.count) > 0 {
            urls.append(URL(fileURLWithPath: String(cString: buf)))
        }
        return urls
    }

    /// Category labels, shared with the review screen.
    public enum Group {
        public static var appCaches: String { L("Caches des apps") }
        public static var temp: String { L("Fichiers temporaires") }
        public static var logs: String { L("Journaux") }
        public static var systemCaches: String { L("Caches système") }
        public static var trash: String { L("Corbeille") }
    }

    private var defaultTargets: [Target] {
        let home = FS.home
        var t: [Target] = [
            Target(url: home.appendingPathComponent("Library/Caches"), group: Group.appCaches, kind: .cache),
            Target(url: home.appendingPathComponent("Library/Logs"), group: Group.logs, kind: .log),
            Target(url: URL(fileURLWithPath: "/Library/Caches"), group: Group.systemCaches, kind: .cache),
            Target(url: URL(fileURLWithPath: "/Library/Logs"), group: Group.logs, kind: .log),
            Target(url: home.appendingPathComponent(".Trash"), group: Group.trash, kind: .trash),
        ]
        for u in Self.userTempFolders() {
            t.append(Target(url: u, group: Group.temp, kind: .tempFile, minAge: 86_400))
        }
        return t
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let targets: [Target]
        if let overrides = rootOverrides {
            targets = overrides.map { Target(url: $0, group: $0.lastPathComponent, kind: .cache) }
        } else {
            targets = defaultTargets
        }

        var items: [ScanItem] = []
        let total = Double(targets.count)
        let fm = FileManager.default
        let now = Date()

        for (idx, target) in targets.enumerated() {
            progress(Double(idx) / total, L("Analyse de \(target.group)…"))
            guard fm.fileExists(atPath: target.url.path) else { continue }
            let children = (try? fm.contentsOfDirectory(
                at: target.url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey],
                options: [])) ?? []

            for child in children {
                if Task.isCancelled { throw ScanError.cancelled }
                let v = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
                if v?.isSymbolicLink == true { continue }
                let modified = FS.modified(of: child)
                if target.minAge > 0, now.timeIntervalSince(modified) < target.minAge { continue }

                if v?.isDirectory == true {
                    var size: Int64 = 0
                    var count = 0
                    for file in FS.enumerate(child, skipHidden: false, shouldCancel: { Task.isCancelled }) {
                        size += FS.size(of: file)
                        count += 1
                    }
                    if Task.isCancelled { throw ScanError.cancelled }
                    guard size > 0 else { continue }
                    items.append(ScanItem(
                        url: child, size: size, modified: modified, kind: target.kind,
                        group: target.group,
                        detail: count == 1 ? L("1 fichier") : L("\(Int(count)) fichiers"),
                        fileCount: count))
                } else if v?.isRegularFile == true {
                    let size = FS.size(of: child)
                    guard size > 0 else { continue }
                    items.append(ScanItem(url: child, size: size, modified: modified,
                                          kind: target.kind, group: target.group))
                }
            }
        }
        progress(1.0, L("Done"))
        return ScanResult(module: .cleanup, items: items)
    }
}
