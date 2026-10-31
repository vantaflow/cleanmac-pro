import Foundation
import AppKit
import UserNotifications
import CleanCore

/// Live state of the macOS permissions, re-checked every time the app becomes
/// active again (typically right after the user toggled it in System Settings).
@MainActor
final class PermissionCenter: ObservableObject {
    static let shared = PermissionCenter()

    @Published private(set) var statuses: [PermissionKind: PermissionStatus] = [
        .fullDiskAccess: .notDetermined, .notifications: .notDetermined, .automation: .notDetermined,
    ]
    /// Banner dismissed for this session only.
    @Published var bannerDismissed = false
    /// UI-test mode: fixed statuses, no system probing.
    var forced: [PermissionKind: PermissionStatus]? {
        didSet { if let forced { statuses = forced } }
    }

    private var observer: NSObjectProtocol?
    private var started = false

    func status(_ kind: PermissionKind) -> PermissionStatus { statuses[kind] ?? .notDetermined }

    /// Starts observing app activation (idempotent) and refreshes once. Never prompts.
    func start() {
        guard !started else { return }
        started = true
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    /// Silent re-check of every permission (no system dialog is ever shown here).
    func refresh() {
        if let forced { statuses = forced; return }
        statuses[.fullDiskAccess] = PermissionDetector.fullDiskAccess()
        statuses[.automation] = PermissionDetector.automationStatus(prompt: false)
        refreshNotifications()
    }

    private func refreshNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = PermissionDetector.notifications(rawAuthorizationStatus: settings.authorizationStatus.rawValue)
            Task { @MainActor in self?.statuses[.notifications] = status }
        }
    }

    func openSettings(_ kind: PermissionKind) {
        NSWorkspace.shared.open(kind.settingsURL)
    }

    /// Asks for notification rights if never asked; otherwise opens the pane.
    /// Call when the user enables scheduled scans.
    func requestNotifications() {
        guard forced == nil, Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                    Task { @MainActor in self?.refreshNotifications() }
                }
            } else {
                Task { @MainActor in self?.refreshNotifications() }
            }
        }
    }

    /// Shows the System Events consent dialog once (only if never answered).
    /// Called when the user opens Performances, never at launch.
    func requestAutomationIfNeeded() {
        guard forced == nil else { return }
        guard PermissionDetector.automationStatus(prompt: false) != .granted,
              status(.automation) != .denied else { return }
        Task.detached(priority: .utility) {
            // System Events must be running for TCC to answer; launch it quietly if needed.
            if NSRunningApplication.runningApplications(withBundleIdentifier: PermissionDetector.systemEventsBundleID).isEmpty {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = false
                cfg.hides = true
                let url = URL(fileURLWithPath: "/System/Library/CoreServices/System Events.app")
                _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            let result = PermissionDetector.automationStatus(prompt: true)
            await MainActor.run { PermissionCenter.shared.statuses[.automation] = result }
        }
    }

    /// Primary action of a permission row.
    func act(on kind: PermissionKind) {
        switch (kind, status(kind)) {
        case (.notifications, .notDetermined): requestNotifications()
        case (.automation, .notDetermined): requestAutomationIfNeeded()
        default: openSettings(kind)
        }
    }
}
