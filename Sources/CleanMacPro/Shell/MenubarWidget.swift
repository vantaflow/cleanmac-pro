import SwiftUI
import CleanCore

/// In-window preview of the menu-bar popover (toggled from the toolbar chip).
/// Shares `HostStats` and layout with the real `MenuBarExtra`.
struct MenubarWidget: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MenuPanelContent(
            onDismiss: { appState.menubarOpen = false },
            onOpenMain: {
                appState.menubarOpen = false
                MainWindow.activate()
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }
}
