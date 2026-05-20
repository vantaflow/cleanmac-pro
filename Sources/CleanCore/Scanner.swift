import Foundation

public protocol FileScanner: Sendable {
    var module: ModuleID { get }
    func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult
}

public struct CleanReport: Hashable {
    public let removedCount: Int
    public let freedBytes: Int64
    public let failedItems: [URL]
}

public enum Cleaner {
    /// Move items to ~/.Trash (safer than rm). Returns report.
    public static func clean(items: [ScanItem], dryRun: Bool = false) -> CleanReport {
        var freed: Int64 = 0
        var removed = 0
        var failed: [URL] = []
        let fm = FileManager.default

        for item in items {
            if dryRun {
                freed += item.size
                removed += 1
                continue
            }
            do {
                var resultingURL: NSURL? = nil
                try fm.trashItem(at: item.url, resultingItemURL: &resultingURL)
                freed += item.size
                removed += 1
            } catch {
                failed.append(item.url)
            }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed)
    }
}
