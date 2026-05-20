import Foundation

public struct LargeFilesScanner: FileScanner {
    public let module: ModuleID = .largeFiles
    public let roots: [URL]
    public let minSize: Int64
    public let oldAge: TimeInterval

    public init(
        roots: [URL]? = nil,
        minSize: Int64 = 50 * 1024 * 1024,  // 50 MB
        oldAge: TimeInterval = 180 * 24 * 3600  // 180 days
    ) {
        self.roots = roots ?? [
            FS.home.appendingPathComponent("Downloads"),
            FS.home.appendingPathComponent("Documents"),
            FS.home.appendingPathComponent("Desktop"),
            FS.home.appendingPathComponent("Movies"),
        ]
        self.minSize = minSize
        self.oldAge = oldAge
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []
        let total = Double(roots.count)
        let now = Date()

        for (idx, root) in roots.enumerated() {
            progress(Double(idx) / total, "Scanning \(root.lastPathComponent)…")
            guard FileManager.default.fileExists(atPath: root.path) else { continue }

            for file in FS.enumerate(root) {
                if Task.isCancelled { throw ScanError.cancelled }
                let size = FS.size(of: file)
                let modified = FS.modified(of: file)
                let age = now.timeIntervalSince(modified)
                let isLarge = size >= minSize
                let isOld = age >= oldAge

                if isLarge || isOld {
                    items.append(ScanItem(
                        url: file,
                        size: size,
                        modified: modified,
                        kind: isLarge ? .largeFile : .oldFile,
                        group: root.lastPathComponent
                    ))
                }
            }
        }
        progress(1.0, "Done")
        items.sort { $0.size > $1.size }
        return ScanResult(module: .largeFiles, items: items)
    }
}
