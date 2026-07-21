import SwiftUI
import AppKit

/// Keeps the app resident in the menu bar after its window is closed — the
/// `sparkles` item stays live until the user quits from the popover.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct CleanMacProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Single main window (reopened via openWindow(id:"main")). Closing it
        // does not quit the app — the MenuBarExtra keeps the process alive.
        Window("CleanMac Pro", id: "main") {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.hostStats)
                .environmentObject(appState.background)
                .environment(\.theme, appState.theme)
                .preferredColorScheme(appState.theme.dark ? .dark : .light)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear { appState.background.activate() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Real menu-bar item — live stats + one-click actions, always in the bar.
        MenuBarExtra("CleanMac Pro", systemImage: "sparkles") {
            MenuPanelContent()
                .environmentObject(appState)
                .environmentObject(appState.hostStats)
                .environmentObject(appState.background)
                .environment(\.theme, appState.theme)
                .onAppear { appState.background.activate() }
        }
        .menuBarExtraStyle(.window)
    }
}
