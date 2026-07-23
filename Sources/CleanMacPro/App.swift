import SwiftUI
import AppKit

/// Bridges SwiftUI's `openWindow` action to AppKit (AppDelegate / status item),
/// so the main window can be reopened after it has been closed.
@MainActor
final class WindowOpener {
    static let shared = WindowOpener()
    var open: (() -> Void)?
}

/// Distinguishes a real quit (from the menu-bar "Quitter" button) from a plain
/// window/⌘Q close, which only hides the app to the menu bar.
@MainActor
final class AppLifecycle {
    static let shared = AppLifecycle()
    var reallyQuit = false
    func quit() { reallyQuit = true; NSApp.terminate(nil) }
}

/// Owns the menu-bar status item directly (an `NSStatusItem`, not SwiftUI's
/// flaky `MenuBarExtra`) so the icon is guaranteed to stay for the whole
/// lifetime of the process — it never vanishes when the window closes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(AppState.shared.background.menuBarOnly ? .accessory : .regular)
        setupStatusItem()
        AppState.shared.background.activate()
    }

    // Closing the window must NOT quit the app — it stays alive in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // ⌘Q / Quit doesn't terminate — it hides the app to the menu bar so the
    // status item stays active even when "closed" (like CleanMyMac's menu).
    // The only real quit is the popover's "Quitter" button (AppLifecycle.quit()).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppLifecycle.shared.reallyQuit { return .terminateNow }
        NSApp.setActivationPolicy(.accessory)
        for window in NSApp.windows where window.isVisible { window.close() }
        return .terminateCancel
    }

    // Clicking the Dock icon (or relaunching) reopens the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { WindowOpener.shared.open?() }
        return true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "CleanMac Pro")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 320, height: 500)
        pop.contentViewController = NSHostingController(
            rootView: MenuPanelContent()
                .environmentObject(AppState.shared)
                .environmentObject(AppState.shared.hostStats)
                .environmentObject(AppState.shared.background)
                .environment(\.theme, AppState.shared.theme)
                .frame(width: 320)
        )

        statusItem = item
        popover = pop
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(sender)
        } else {
            AppState.shared.background.activate()
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
}

@main
struct CleanMacProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Single main window. Closing it does not quit the app — the status
        // item (owned by AppDelegate) keeps the process alive, and this window
        // can be reopened via the menu bar or the Dock icon.
        Window("CleanMac Pro", id: "main") {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.hostStats)
                .environmentObject(appState.background)
                .environment(\.theme, appState.theme)
                .preferredColorScheme(appState.theme.dark ? .dark : .light)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear { appState.background.activate() }
                .background(WindowOpenerBridge())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Captures SwiftUI's `openWindow` action into `WindowOpener.shared` so AppKit
/// code (Dock reopen, status-item panel) can reopen the main window.
private struct WindowOpenerBridge: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear {
                WindowOpener.shared.open = {
                    NSApp.setActivationPolicy(AppState.shared.background.menuBarOnly ? .accessory : .regular)
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
