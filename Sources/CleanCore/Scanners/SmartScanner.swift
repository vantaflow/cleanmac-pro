import Foundation

/// One-shot "Smart Scan": runs the space-reclaiming and posture scanners in
/// parallel and merges everything into a single `.smartScan` result. Each item
/// keeps its own `kind`, so the UI still renders per-category rows and
/// `Cleaner`/`AppState.clean` still filter out non-cleanable findings
/// (security, updates, processes, …).
///
/// With `rootOverrides` set, it behaves as a deterministic, offline scan over
/// the given directories (used by tests and by callers that want a fast,
/// network-free pass).
public struct SmartScanner: FileScanner {
    public let module: ModuleID = .smartScan
    public let rootOverrides: [URL]?
    private let includePosture: Bool
    private let useCache: Bool
    private let maxCacheAge: TimeInterval

    /// - Parameters:
    ///   - rootOverrides: when set, scans exactly these directories (cleanup
    ///     semantics) and skips everything network-bound.
    ///   - includePosture: include read-only posture checks (security,
    ///     updates) in addition to the reclaimable modules. Defaults to `true`
    ///     for a full scan; ignored when `rootOverrides` is set.
    ///   - useCache: reuse a recent, still-valid scan via `ScanCache` instead
    ///     of re-walking the tree (the background agent uses this).
    public init(rootOverrides: [URL]? = nil, includePosture: Bool = true,
                useCache: Bool = false, maxCacheAge: TimeInterval = 600) {
        self.rootOverrides = rootOverrides
        self.includePosture = includePosture
        self.useCache = useCache
        self.maxCacheAge = maxCacheAge
    }

    /// Directories whose mtime invalidates the cache.
    private var fingerprintRoots: [URL] {
        if let overrides = rootOverrides { return overrides }
        let home = FS.home
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Movies"),
        ]
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let roots = fingerprintRoots

        if useCache, let cached = await ScanCache.shared.cached(.smartScan, roots: roots, maxAge: maxCacheAge) {
            progress(1.0, "À jour (cache)")
            return ScanResult(module: .smartScan, items: cached)
        }

        if let overrides = rootOverrides {
            let result = try await CleanupScanner(rootOverrides: overrides)
                .scan(progress: progress)
            if useCache { await ScanCache.shared.save(.smartScan, roots: roots, items: result.items) }
            return ScanResult(module: .smartScan, items: result.items)
        }

        var scanners: [any FileScanner] = [
            CleanupScanner(),
            FilesScanner(),
            PrivacyScanner(),
        ]
        if includePosture {
            scanners.append(SecurityScanner())
            scanners.append(UpdatesScanner())
        }

        let total = scanners.count
        let counter = ProgressCounter(total: total)

        var merged: [ScanItem] = []
        try await withThrowingTaskGroup(of: ScanResult.self) { group in
            for scanner in scanners {
                group.addTask {
                    let r = try await scanner.scan { _, _ in }
                    return r
                }
            }
            for try await result in group {
                let done = counter.increment()
                progress(Double(done) / Double(total),
                         "Smart Scan — \(result.module.title) (\(done)/\(total))")
                merged.append(contentsOf: result.items)
            }
        }

        if useCache { await ScanCache.shared.save(.smartScan, roots: roots, items: merged) }
        progress(1.0, "Done")
        return ScanResult(module: .smartScan, items: merged)
    }
}

/// Thread-safe completion counter for aggregating parallel sub-scan progress.
private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var done = 0
    let total: Int
    init(total: Int) { self.total = total }
    func increment() -> Int { lock.lock(); done += 1; let v = done; lock.unlock(); return v }
}
