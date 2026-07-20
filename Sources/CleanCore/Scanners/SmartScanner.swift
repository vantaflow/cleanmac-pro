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

    /// - Parameters:
    ///   - rootOverrides: when set, scans exactly these directories (cleanup
    ///     semantics) and skips everything network-bound.
    ///   - includePosture: include read-only posture checks (security,
    ///     updates) in addition to the reclaimable modules. Defaults to `true`
    ///     for a full scan; ignored when `rootOverrides` is set.
    public init(rootOverrides: [URL]? = nil, includePosture: Bool = true) {
        self.rootOverrides = rootOverrides
        self.includePosture = includePosture
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        if let overrides = rootOverrides {
            let result = try await CleanupScanner(rootOverrides: overrides)
                .scan(progress: progress)
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
