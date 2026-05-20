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
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return ScanResult(module: .spaceLens, items: [])
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
                url: child,
                size: size,
                modified: FS.modified(of: child),
                kind: .spaceFolder,
                group: root.lastPathComponent,
                title: child.lastPathComponent,
                detail: child.path,
                severity: .info
            ))
        }
        items.sort { $0.size > $1.size }
        progress(1.0, "Done")
        return ScanResult(module: .spaceLens, items: items)
    }
}
