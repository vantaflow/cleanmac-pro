import Foundation

/// Minimal helper to run shell tools and capture stdout. Used by scanners that
/// query system state via existing macOS CLIs (fdesetup, spctl, launchctl, …).
public enum Shell {
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
            return (-1, "", "launch failed: \(error)")
        }
        // Naive timeout
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if p.isRunning {
            p.terminate()
            return (-2, "", "timeout")
        }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        return (
            p.terminationStatus,
            String(data: outData, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
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
            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
