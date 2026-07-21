import Foundation
import AppKit
import UserNotifications
import CleanCore

/// Runs Smart Scans on a schedule in the background, remembers the last known
/// recoverable amount (so the menu bar shows "veille active" before any manual
/// scan), posts a notification when there's meaningful space to reclaim, and
/// owns the menu-bar-only (accessory) activation mode.
@MainActor
final class BackgroundAgent: ObservableObject {
    // Persisted preferences
    @Published var scheduledScanEnabled: Bool {
        didSet {
            UserDefaults.standard.set(scheduledScanEnabled, forKey: Keys.scheduled)
            reschedule()
        }
    }
    @Published var menuBarOnly: Bool {
        didSet {
            UserDefaults.standard.set(menuBarOnly, forKey: Keys.menuOnly)
            applyActivationPolicy()
        }
    }

    // Last scan memory (survives relaunch)
    @Published private(set) var lastRecoverableBytes: Int64
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var isScanning = false

    /// Re-scan interval and the notify threshold (1 GB).
    private let interval: TimeInterval = 6 * 3600
    private let notifyThreshold: Int64 = 1_000_000_000
    private var timer: Timer?
    private var activated = false

    private enum Keys {
        static let scheduled = "ai.turkeycode.cleanmacpro.bg.scheduled"
        static let menuOnly  = "ai.turkeycode.cleanmacpro.bg.menuOnly"
        static let lastBytes = "ai.turkeycode.cleanmacpro.bg.lastBytes"
        static let lastDate  = "ai.turkeycode.cleanmacpro.bg.lastDate"
    }

    init() {
        let d = UserDefaults.standard
        scheduledScanEnabled = d.bool(forKey: Keys.scheduled)
        menuBarOnly = d.bool(forKey: Keys.menuOnly)
        lastRecoverableBytes = Int64(d.integer(forKey: Keys.lastBytes))
        let ts = d.double(forKey: Keys.lastDate)
        lastScanDate = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// Call at launch, after the scene is up. Idempotent.
    func activate() {
        guard !activated else { return }
        activated = true
        applyActivationPolicy()
        requestNotificationAuthIfPossible()
        reschedule()
    }

    // MARK: — Scheduling

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard scheduledScanEnabled else { return }
        // Kick one off shortly after enabling, then on the interval.
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runScan(notify: true) }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await self.runScan(notify: true)
        }
    }

    /// Runs a Smart Scan off the main thread; updates the remembered total.
    func runScan(notify: Bool) async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let bytes: Int64 = await Task.detached(priority: .utility) {
            let result = try? await SmartScanner(useCache: true).scan(progress: { _, _ in })
            return result?.totalSize ?? 0
        }.value

        lastRecoverableBytes = bytes
        lastScanDate = Date()
        let d = UserDefaults.standard
        d.set(Int(bytes), forKey: Keys.lastBytes)
        d.set(lastScanDate!.timeIntervalSince1970, forKey: Keys.lastDate)

        if notify && bytes >= notifyThreshold {
            postNotification(bytes: bytes)
        }
    }

    // MARK: — Notifications

    /// Ask once; safe no-op when running without a bundle id (e.g. `swift run`),
    /// where `UNUserNotificationCenter.current()` would trap.
    func requestNotificationAuthIfPossible() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification(bytes: Int64) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "CleanMac Pro"
        content.body = "\(ByteFormatter.string(bytes)) récupérables sur ton Mac."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "cmp.recoverable",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: — Activation policy (menu-bar-only)

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }
}
