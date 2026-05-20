import Foundation
import CryptoKit

public struct DuplicatesScanner: FileScanner {
    public let module: ModuleID = .duplicates
    public let roots: [URL]
    public let minSize: Int64

    public init(roots: [URL]? = nil, minSize: Int64 = 1 * 1024 * 1024) {
        self.roots = roots ?? [
            FS.home.appendingPathComponent("Downloads"),
            FS.home.appendingPathComponent("Documents"),
            FS.home.appendingPathComponent("Desktop"),
            FS.home.appendingPathComponent("Pictures"),
        ]
        self.minSize = minSize
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        // Step 1: group files by size (cheap filter)
        progress(0.05, "Indexing files…")
        var bySize: [Int64: [URL]] = [:]
        for root in roots {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            for file in FS.enumerate(root, skipHidden: true) {
                if Task.isCancelled { throw ScanError.cancelled }
                let size = FS.size(of: file)
                guard size >= minSize else { continue }
                bySize[size, default: []].append(file)
            }
        }

        // Only sizes with 2+ candidates need hashing
        let candidates = bySize.filter { $0.value.count > 1 }
        let total = max(candidates.count, 1)

        // Step 2: hash candidates
        var byHash: [String: [(URL, Int64)]] = [:]
        for (idx, (size, urls)) in candidates.enumerated() {
            progress(0.1 + 0.9 * Double(idx) / Double(total), "Hashing duplicates…")
            for url in urls {
                if Task.isCancelled { throw ScanError.cancelled }
                guard let h = hash(url: url) else { continue }
                byHash[h, default: []].append((url, size))
            }
        }

        // Step 3: emit items for groups with 2+ identical hashes
        var items: [ScanItem] = []
        for (hash, files) in byHash where files.count > 1 {
            // Keep first as "original", mark rest as duplicates
            for (i, (url, size)) in files.enumerated() {
                items.append(ScanItem(
                    url: url,
                    size: size,
                    modified: FS.modified(of: url),
                    kind: .duplicate,
                    group: "\(hash.prefix(8)) (\(i == 0 ? "keep" : "dup"))"
                ))
            }
        }

        progress(1.0, "Done")
        return ScanResult(module: .duplicates, items: items)
    }

    private func hash(url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read < 0 { return nil }
            if read == 0 { break }
            hasher.update(data: Data(buffer[0..<read]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
