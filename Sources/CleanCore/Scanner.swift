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

    /// Fallback for items `trashItem` can't move (root-owned bundles like App
    /// Store apps): move them into ~/.Trash with a single admin-authenticated
    /// shell call (one native password prompt for the whole batch). Still safe
    /// — items land in the Trash, not `rm`'d — and restorable.
    public static func trashWithAdmin(items: [ScanItem]) -> CleanReport {
        guard !items.isEmpty else { return CleanReport(removedCount: 0, freedBytes: 0, failedItems: []) }
        let fm = FileManager.default
        let trashDir = NSHomeDirectory() + "/.Trash"

        let cmds = items.map { item -> String in
            let dest = trashDir + "/" + item.url.lastPathComponent
            return "/bin/mv -f \(singleQuoted(item.url.path)) \(singleQuoted(dest))"
        }
        let shell = cmds.joined(separator: "; ")
        // Embed into an AppleScript string literal (escape backslash then quote).
        let esc = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(esc)\" with administrator privileges"
        _ = Shell.run("/usr/bin/osascript", ["-e", script], timeout: 300)

        // Whatever no longer exists at its source was moved successfully.
        var freed: Int64 = 0
        var removed = 0
        var failed: [URL] = []
        for item in items {
            if fm.fileExists(atPath: item.url.path) {
                failed.append(item.url)
            } else {
                freed += item.size
                removed += 1
            }
        }
        return CleanReport(removedCount: removed, freedBytes: freed, failedItems: failed)
    }

    /// POSIX single-quote a path, escaping embedded single quotes.
    private static func singleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
