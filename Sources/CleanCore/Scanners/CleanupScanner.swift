import Foundation

public struct CleanupScanner: FileScanner {
    public let module: ModuleID = .cleanup
    public var rootOverrides: [URL]?  // for tests

    public init(rootOverrides: [URL]? = nil) {
        self.rootOverrides = rootOverrides
    }

    private var defaultTargets: [(URL, String, ItemKind)] {
        let home = FS.home
        return [
            (home.appendingPathComponent("Library/Caches"),    "User Caches",     .cache),
            (home.appendingPathComponent("Library/Logs"),      "User Logs",       .log),
            (URL(fileURLWithPath: "/Library/Caches"),          "System Caches",   .cache),
            (URL(fileURLWithPath: "/Library/Logs"),            "System Logs",     .log),
            (home.appendingPathComponent(".Trash"),            "Trash",           .trash),
            (URL(fileURLWithPath: "/private/var/folders"),     "Temp Files",      .tempFile),
        ]
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let targets: [(URL, String, ItemKind)]
        if let overrides = rootOverrides {
            targets = overrides.map { ($0, $0.lastPathComponent, .cache) }
        } else {
            targets = defaultTargets
        }

        var items: [ScanItem] = []
        let total = Double(targets.count)
        let fm = FileManager.default

        for (idx, (url, label, kind)) in targets.enumerated() {
            progress(Double(idx) / total, "Scanning \(label)…")
            guard fm.fileExists(atPath: url.path) else { continue }

            for file in FS.enumerate(url, skipHidden: false) {
                if Task.isCancelled { throw ScanError.cancelled }
                let size = FS.size(of: file)
                guard size > 0 else { continue }
                items.append(ScanItem(
                    url: file,
                    size: size,
                    modified: FS.modified(of: file),
                    kind: kind,
                    group: label
                ))
            }
        }
        progress(1.0, "Done")
        return ScanResult(module: .cleanup, items: items)
    }
}
