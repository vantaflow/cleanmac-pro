import Foundation

/// Disk-usage treemap data. Scans a curated set of accessible top-level
/// directories on the system so the treemap has something to draw even
/// without Full Disk Access. Falls back to FileManager enumeration if `du`
/// fails on a given root.
public struct SpaceLensScanner: FileScanner {
    public let module: ModuleID = .spaceLens
    public let roots: [URL]

    public init(roots: [URL]? = nil) {
        if let roots {
            self.roots = roots
        } else {
            let home = FS.home
            // Curated list of directories that are typically readable without
            // entitlements OR are commonly the largest space hogs.
            self.roots = [
                URL(fileURLWithPath: "/Applications"),
                home.appendingPathComponent("Applications"),
                home.appendingPathComponent("Library/Caches"),
                home.appendingPathComponent("Library/Application Support"),
                home.appendingPathComponent("Library/Containers"),
                home.appendingPathComponent("Library/Logs"),
                home.appendingPathComponent("Downloads"),
                home.appendingPathComponent("Documents"),
                home.appendingPathComponent("Desktop"),
                home.appendingPathComponent("Movies"),
                home.appendingPathComponent("Music"),
                home.appendingPathComponent("Pictures"),
            ]
        }
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []
        let total = Double(roots.count)
        let fm = FileManager.default

        for (idx, root) in roots.enumerated() {
            if Task.isCancelled { throw ScanError.cancelled }
            progress(Double(idx) / total, "Analyse \(root.lastPathComponent)…")

            guard fm.fileExists(atPath: root.path) else { continue }

            // Prefer `du -sk` for speed; fall back to FileManager.
            var size = duSize(root)
            if size == 0 { size = FS.directorySize(root, shouldCancel: { Task.isCancelled }) }
            guard size > 0 else { continue }

            let group: String
            if root.path.hasPrefix("/Applications") { group = "Système" }
            else if root.path.contains("/Library/")  { group = "~/Library" }
            else                                     { group = "Utilisateur" }

            items.append(ScanItem(
                url: root,
                size: size,
                modified: FS.modified(of: root),
                kind: .spaceFolder,
                group: group,
                title: friendlyName(root),
                detail: root.path,
                severity: .info
            ))
        }

        items.sort { $0.size > $1.size }
        progress(1.0, "Done")

        if items.isEmpty {
            // Nothing readable — surface a single informative item so the UI isn't blank.
            return ScanResult(module: .spaceLens, items: [
                ScanItem(
                    url: FS.home, size: 0, kind: .spaceFolder,
                    group: "Permissions",
                    title: "Lecture refusée",
                    detail: "Donne à CleanMac Pro l'accès « Fichiers et dossiers » dans Réglages → Confidentialité → Fichiers et dossiers.",
                    severity: .warn
                )
            ])
        }
        return ScanResult(module: .spaceLens, items: items)
    }

    /// Runs `du -sk <path>` and returns the size in bytes, or 0 on failure.
    private func duSize(_ url: URL) -> Int64 {
        let (status, out, _) = Shell.run("/usr/bin/du", ["-sk", url.path], timeout: 60)
        guard status == 0 else { return 0 }
        let firstLine = out.split(separator: "\n").first.map(String.init) ?? ""
        let parts = firstLine.split(separator: "\t", maxSplits: 1).map(String.init)
        guard let kb = Int64(parts.first?.trimmingCharacters(in: .whitespaces) ?? "0") else { return 0 }
        return kb * 1024
    }

    private func friendlyName(_ url: URL) -> String {
        let p = url.path
        if p == "/Applications" { return "/Applications" }
        if p.hasPrefix(FS.home.path) {
            let rel = String(p.dropFirst(FS.home.path.count))
            return "~" + rel
        }
        return url.lastPathComponent
    }
}
