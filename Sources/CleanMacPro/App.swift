import SwiftUI

@main
struct CleanMacProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("CleanMac Pro") {
            DashboardView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
