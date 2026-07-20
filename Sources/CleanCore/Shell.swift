import Foundation

/// Minimal helper to run shell tools and capture stdout. Used by scanners that
/// query system state via existing macOS CLIs (fdesetup, spctl, launchctl, …).
public enum Shell {
    /// Exit status returned when the process could not be launched at all.
    public static let launchFailed: Int32 = -1
    /// Exit status returned when the process was killed for exceeding `timeout`.
    public static let timedOut: Int32 = -2

    @discardableResult
    public static func run(_ executable: String, _ args: [String], timeout: TimeInterval = 30) -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        do {
            try p.run()
        } catch {
            return (launchFailed, "", "launch failed: \(error)")
        }

        // Drain both pipes concurrently on background queues. This is essential:
        // if a child writes more than the pipe buffer (~64 KB) we must keep
        // reading, otherwise the child blocks on write, never exits, and we'd
        // kill it at the timeout with truncated output. `readDataToEndOfFile`
        // returns once the pipe reaches EOF (child exits or is terminated).
        var outData = Data()
        var errData = Data()
        let ioGroup = DispatchGroup()
        let ioQueue = DispatchQueue(label: "ai.turkeycode.cleanmacpro.shell-io", attributes: .concurrent)
        ioGroup.enter()
        ioQueue.async {
            outData = out.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }
        ioGroup.enter()
        ioQueue.async {
            errData = err.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }

        // Enforce the timeout without busy-waiting: a one-shot work item
        // terminates the process if it's still running when the deadline hits.
        let timeoutFlag = TimeoutFlag()
        let killer = DispatchWorkItem {
            if p.isRunning {
                timeoutFlag.trip()
                p.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

        p.waitUntilExit()
        killer.cancel()
        ioGroup.wait()

        if timeoutFlag.tripped {
            return (timedOut, "", "timeout")
        }
        return (
            p.terminationStatus,
            String(decoding: outData, as: UTF8.self),
            String(decoding: errData, as: UTF8.self)
        )
    }

    /// Look up an executable in common locations.
    public static func which(_ name: String) -> String? {
        let candidates = [
            "/usr/local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
            "/sbin/\(name)",
            "/usr/sbin/\(name)",
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
        let (status, out, _) = run("/usr/bin/which", [name])
        if status == 0 {
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}

/// Thread-safe one-way flag: set from the timeout work item, read after join.
private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func trip() { lock.lock(); value = true; lock.unlock() }
    var tripped: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
