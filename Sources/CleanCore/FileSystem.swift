import Foundation

public enum FS {
    /// Recursively enumerate files under a directory. Skips symlinks.
    public static func enumerate(
        _ root: URL,
        skipHidden: Bool = false,
        shouldCancel: @escaping () -> Bool = { false }
    ) -> AnyIterator<URL> {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey]
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if skipHidden { options.insert(.skipsHiddenFiles) }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: options,
            errorHandler: { _, _ in true }
        )
        return AnyIterator {
            while let next = enumerator?.nextObject() as? URL {
                if shouldCancel() { return nil }
                let values = try? next.resourceValues(forKeys: Set(keys))
                if values?.isSymbolicLink == true { continue }
                if values?.isRegularFile == true { return next }
            }
            return nil
        }
    }

    public static func size(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
        if let alloc = values?.totalFileAllocatedSize { return Int64(alloc) }
        if let size = values?.fileSize { return Int64(size) }
        return 0
    }

    public static func modified(of url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? Date.distantPast
    }

    public static func directorySize(_ url: URL, shouldCancel: @escaping () -> Bool = { false }) -> Int64 {
        var total: Int64 = 0
        for file in enumerate(url, shouldCancel: shouldCancel) {
            total += size(of: file)
        }
        return total
    }

    public static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    public static func expand(_ path: String) -> URL {
        let ns = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: ns)
    }
}

public enum ByteFormatter {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f
    }()

    public static func string(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: max(0, bytes))
    }
}
