import SwiftUI

@main
struct CleanMacProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("CleanMac Pro", id: "main") {
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
            MenuPanelContent(onOpenMain: { MainWindow.activate() })
                .environmentObject(appState)
                .environmentObject(appState.hostStats)
                .environmentObject(appState.background)
                .environment(\.theme, appState.theme)
                .onAppear { appState.background.activate() }
        }
        .menuBarExtraStyle(.window)
    }
}
