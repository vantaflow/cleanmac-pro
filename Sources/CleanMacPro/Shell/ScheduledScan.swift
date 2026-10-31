import Foundation
import AppKit
import UserNotifications
import CleanCore

/// Installs / removes the scheduled-scan LaunchAgent.
///
/// Why a LaunchAgent that relaunches the binary rather than the in-app
/// `BackgroundAgent` timer: the timer only works while the app is running,
/// whereas launchd fires at a fixed time even after a reboot or a quit, and
/// the scan process exits right after notifying (no resident cost).
enum ScheduleInstaller {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "ai.turkeycode.cleanmacpro" }

    static func apply(_ schedule: ScanSchedule) {
        guard let exe = Bundle.main.executablePath else { return }
        let label = ScheduledScanAgent.label(bundleID: bundleID)
        let domain = "gui/\(getuid())"
        // Unload any previous version first (ignore failure: may not be loaded).
        _ = Shell.run("/bin/launchctl", ["bootout", "\(domain)/\(label)"])
        do {
            if let url = try ScheduledScanAgent.sync(bundleID: bundleID, executablePath: exe, schedule: schedule) {
                _ = Shell.run("/bin/launchctl", ["bootstrap", domain, url.path])
            }
        } catch {
            // Best effort (read-only LaunchAgents folder, sandbox…).
        }
    }
}

/// `CleanMacPro --scheduled-scan`: silent Cleanup + Files + Developer scan (nothing is
/// deleted), notification with the recoverable amount, then exit.
@MainActor
enum ScheduledScan {
    static func runAndExit() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task {
            await perform()
            exit(0)
        }
        app.run()
    }

    private static func perform() async {
        let exclusions = ExclusionList.load()
        let scanners: [any FileScanner] = [CleanupScanner(), FilesScanner(), DeveloperScanner(includeTools: false)]
        var bytes: Int64 = 0
        for s in scanners {
            if let r = try? await s.scanFiltered(exclusions: exclusions, progress: { _, _ in }) {
                bytes += r.totalSize
            }
        }
        let d = UserDefaults.standard
        d.set(Int(bytes), forKey: "ai.turkeycode.cleanmacpro.bg.lastBytes")
        d.set(Date().timeIntervalSince1970, forKey: "ai.turkeycode.cleanmacpro.bg.lastDate")
        await notify(bytes: bytes)
    }

    private static func notify(bytes: Int64) async {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "CleanMac Pro"
        content.body = "\(ByteFormatter.string(bytes)) récupérables sur ton Mac."
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: "cmp.scheduled", content: content, trigger: nil))
        try? await Task.sleep(nanoseconds: 1_500_000_000)   // let the notification be delivered
    }
}
