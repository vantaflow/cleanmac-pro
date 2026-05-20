import SwiftUI

@main
struct CleanMacProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("CleanMac Pro") {
            RootView()
                .environmentObject(appState)
                .environment(\.theme, appState.theme)
                .preferredColorScheme(appState.theme.dark ? .dark : .light)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
