import Foundation

/// Disk-usage treemap data. Scans the home directory's top-level children,
/// reports each as a ScanItem with size = directory size. The UI renders this
/// as a treemap.
public struct SpaceLensScanner: FileScanner {
    public let module: ModuleID = .spaceLens
    public let root: URL

    public init(root: URL? = nil) {
        self.root = root ?? FS.home
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        // Prefer `du` — it's fast and accurate, and handles errors silently
        // for paths we can't read (no exception bubbling up).
        if let duItems = try? duChildren(of: root, progress: progress), !duItems.isEmpty {
            progress(1.0, "Done")
            return ScanResult(module: .spaceLens, items: duItems)
        }
        // Fallback: per-child directory enumeration via FileManager.
        return try await fallbackScan(progress: progress)
    }

    private func duChildren(of dir: URL, progress: @escaping (Double, String) -> Void) throws -> [ScanItem] {
        progress(0.1, "Calcul des tailles avec du…")
        // -s : summarize, -k : KB. Argument expansion via shell so we can use wildcards.
        let (status, out, _) = Shell.run(
            "/bin/sh",
            ["-c", "/usr/bin/du -sk \"\(dir.path)\"/* \"\(dir.path)\"/.??* 2>/dev/null | sort -rn"],
            timeout: 120
        )
        guard status == 0 || !out.isEmpty else { return [] }
        var items: [ScanItem] = []
        for raw in out.split(separator: "\n") {
            let line = String(raw)
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2, let kb = Int64(parts[0]) else { continue }
            let path = parts[1]
            let url = URL(fileURLWithPath: path)
            items.append(ScanItem(
                url: url,
                size: kb * 1024,
                modified: FS.modified(of: url),
                kind: .spaceFolder,
                group: dir.lastPathComponent,
                title: url.lastPathComponent,
                detail: path,
                severity: .info
            ))
        }
        return items
    }

    private func fallbackScan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return ScanResult(module: .spaceLens, items: [
                ScanItem(
                    url: root, size: 0, kind: .spaceFolder,
                    group: "Permissions",
                    title: "Lecture refusée",
                    detail: "Donne à CleanMac Pro l'accès Full Disk Access dans Réglages → Confidentialité.",
                    severity: .warn
                )
            ])
        }
        let total = Double(max(children.count, 1))
        var items: [ScanItem] = []
        for (idx, child) in children.enumerated() {
            if Task.isCancelled { throw ScanError.cancelled }
            progress(Double(idx) / total, "Analyse \(child.lastPathComponent)…")
            var isDir: ObjCBool = false
            fm.fileExists(atPath: child.path, isDirectory: &isDir)
            let size = isDir.boolValue
                ? FS.directorySize(child, shouldCancel: { Task.isCancelled })
                : FS.size(of: child)
            if size == 0 { continue }
            items.append(ScanItem(
                url: child, size: size,
                modified: FS.modified(of: child),
                kind: .spaceFolder,
                group: root.lastPathComponent,
                title: child.lastPathComponent,
                detail: child.path,
                severity: .info
            ))
        }
        items.sort { $0.size > $1.size }
        return ScanResult(module: .spaceLens, items: items)
    }
}
