import Foundation
import CoreGraphics
import ImageIO

/// BK-tree over 64-bit hashes with the Hamming metric: radius queries avoid
/// the naive O(n²) pairwise comparison.
struct BKTree {
    private struct Node {
        let hash: UInt64
        var members: [Int]
        var children: [Int: Int]
    }
    private var nodes: [Node] = []

    mutating func insert(hash: UInt64, index: Int) {
        guard !nodes.isEmpty else {
            nodes.append(Node(hash: hash, members: [index], children: [:]))
            return
        }
        var cur = 0
        while true {
            let d = (nodes[cur].hash ^ hash).nonzeroBitCount
            if d == 0 { nodes[cur].members.append(index); return }
            if let next = nodes[cur].children[d] {
                cur = next
            } else {
                nodes.append(Node(hash: hash, members: [index], children: [:]))
                nodes[cur].children[d] = nodes.count - 1
                return
            }
        }
    }

    /// Indices of every inserted hash within `radius` bits of `hash`.
    func search(hash: UInt64, radius: Int) -> [Int] {
        guard !nodes.isEmpty else { return [] }
        var out: [Int] = []
        var stack = [0]
        while let i = stack.popLast() {
            let d = (nodes[i].hash ^ hash).nonzeroBitCount
            if d <= radius { out += nodes[i].members }
            for (dist, child) in nodes[i].children where abs(dist - d) <= radius {
                stack.append(child)
            }
        }
        return out
    }
}

/// Finds visually similar (not only byte-identical) photos with a 64-bit
/// difference hash (dHash on a 9×8 grayscale thumbnail), clusters them by
/// Hamming distance, and proposes to keep the best of each group (highest
/// resolution, then most recent). The kept photo is listed as `.keeper`
/// (never cleaned); the others are `.duplicate` and go to the Trash.
/// Perfectly flat images (hash 0) are ignored: they would all look alike.
public struct SimilarPhotosScanner: FileScanner {
    public let module: ModuleID = .similarPhotos
    public let roots: [URL]
    public let threshold: Int
    public let maxImages: Int
    public let minFileSize: Int64

    static let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "tif"]

    public init(roots: [URL]? = nil, threshold: Int = 6, maxImages: Int = 20_000, minFileSize: Int64 = 2048) {
        self.roots = roots ?? [
            FS.home.appendingPathComponent("Pictures"),
            FS.home.appendingPathComponent("Downloads"),
            FS.home.appendingPathComponent("Desktop"),
        ]
        self.threshold = threshold
        self.maxImages = maxImages
        self.minFileSize = minFileSize
    }

    private struct Record: Sendable {
        let url: URL
        let size: Int64
        let modified: Date
        var width = 0
        var height = 0
        var hash: UInt64 = 0
        var pixels: Int { width * height }
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.02, "Recherche d'images…")
        var candidates: [Record] = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            for file in FS.enumerate(root, skipHidden: true) {
                if Task.isCancelled { throw ScanError.cancelled }
                guard Self.extensions.contains(file.pathExtension.lowercased()),
                      !file.path.contains(".photoslibrary/") else { continue }
                let size = FS.size(of: file)
                guard size >= minFileSize else { continue }
                candidates.append(Record(url: file, size: size, modified: FS.modified(of: file)))
            }
        }
        // Bounded work: keep the most recent images when there are too many.
        if candidates.count > maxImages {
            candidates.sort { $0.modified > $1.modified }
            candidates = Array(candidates.prefix(maxImages))
        }

        // Hash in parallel batches.
        var records: [Record] = []
        let batch = max(4, ProcessInfo.processInfo.activeProcessorCount * 4)
        var start = 0
        while start < candidates.count {
            if Task.isCancelled { throw ScanError.cancelled }
            let slice = Array(candidates[start..<min(start + batch, candidates.count)])
            let done: [Record] = await withTaskGroup(of: Record?.self) { group in
                for rec in slice {
                    group.addTask {
                        guard let a = Self.analyze(url: rec.url), a.hash != 0 else { return nil }
                        var r = rec
                        r.hash = a.hash; r.width = a.width; r.height = a.height
                        return r
                    }
                }
                var out: [Record] = []
                for await r in group { if let r { out.append(r) } }
                return out
            }
            records += done
            start += slice.count
            progress(0.05 + 0.85 * Double(start) / Double(max(candidates.count, 1)),
                     "Empreintes perceptuelles \(start)/\(candidates.count)…")
        }
        records.sort { $0.url.path < $1.url.path }   // deterministic

        // Cluster with a BK-tree + union-find.
        progress(0.92, "Regroupement…")
        var tree = BKTree()
        for (i, r) in records.enumerated() { tree.insert(hash: r.hash, index: i) }
        var parent = Array(0..<records.count)
        func find(_ x: Int) -> Int {
            var x = x
            while parent[x] != x { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        for (i, r) in records.enumerated() {
            for j in tree.search(hash: r.hash, radius: threshold) where j != i {
                let a = find(i), b = find(j)
                if a != b { parent[a] = b }
            }
        }
        var clusters: [Int: [Int]] = [:]
        for i in records.indices { clusters[find(i), default: []].append(i) }

        // One group per cluster: best first (resolution, then recency).
        var groups: [[Record]] = clusters.values.filter { $0.count > 1 }.map { idxs in
            idxs.map { records[$0] }.sorted {
                if $0.pixels != $1.pixels { return $0.pixels > $1.pixels }
                if $0.modified != $1.modified { return $0.modified > $1.modified }
                if $0.size != $1.size { return $0.size > $1.size }
                return $0.url.path < $1.url.path
            }
        }
        func reclaimable(_ g: [Record]) -> Int64 { g.dropFirst().reduce(0) { $0 + $1.size } }
        groups.sort { reclaimable($0) > reclaimable($1) }

        var items: [ScanItem] = []
        for (n, g) in groups.enumerated() {
            let best = g[0]
            let label = "Groupe \(n + 1) · \(best.url.lastPathComponent)"
            items.append(ScanItem(
                url: best.url, size: 0, modified: best.modified, kind: .keeper, group: label,
                detail: "À garder — meilleure version · \(best.width)×\(best.height) · \(ByteFormatter.string(best.size))",
                severity: .good))
            for r in g.dropFirst() {
                let d = (r.hash ^ best.hash).nonzeroBitCount
                items.append(ScanItem(
                    url: r.url, size: r.size, modified: r.modified, kind: .duplicate, group: label,
                    detail: "Similaire · \(r.width)×\(r.height) · écart \(d)/64"))
            }
        }
        progress(1.0, "Done")
        return ScanResult(module: .similarPhotos, items: items)
    }

    // MARK: perceptual hash

    /// dHash (64 bits) + pixel dimensions of an image file, or nil if unreadable.
    public static func analyze(url: URL) -> (hash: UInt64, width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithURL(
            url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        var w = 0, h = 0
        if let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            w = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
            h = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 160,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        if w == 0 || h == 0 { w = thumb.width; h = thumb.height }
        return (dHash(of: thumb), w, h)
    }

    /// Difference hash: 9×8 grayscale, bit = pixel(x) < pixel(x+1) per row.
    public static func dHash(of image: CGImage) -> UInt64 {
        let cw = 9, ch = 8
        var pixels = [UInt8](repeating: 0, count: cw * ch)
        let drawn = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: cw, height: ch,
                                      bitsPerComponent: 8, bytesPerRow: cw,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: cw, height: ch))
            return true
        }
        guard drawn else { return 0 }
        var hash: UInt64 = 0
        for y in 0..<ch {
            for x in 0..<(cw - 1) where pixels[y * cw + x] < pixels[y * cw + x + 1] {
                hash |= UInt64(1) << UInt64(y * 8 + x)
            }
        }
        return hash
    }
}
