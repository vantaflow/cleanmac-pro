import SwiftUI
import CleanCore

/// Window shell: graphite canvas, sidebar on the left, the active module's
/// screen on the right.
struct RootView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                IconRail()
                ContentPane()
            }
            .background(Color.canvas(theme.dark))
            .ignoresSafeArea()

            if appState.menubarOpen {
                MenubarWidget()
                    .padding(.top, 40)
                    .padding(.trailing, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if appState.showOnboarding {
                OnboardingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: appState.menubarOpen)
        .animation(.easeOut(duration: 0.35), value: appState.showOnboarding)
        .onAppear { appState.refreshDisk() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in appState.refreshDisk() }
    }
}

/// Hosts the active module's screen, directly on the gradient.
private struct ContentPane: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    private var themed: Theme {
        var t = theme   // keeps the effective light/dark from `.themed(_:)`
        t.accent = appState.active.accentEnum
        return t
    }

    var body: some View {
        VStack(spacing: 0) {
            PermissionBanner(module: appState.active)
            content
        }
        .environment(\.theme, themed)
    }

    private var content: some View {
        Group {
            switch appState.active {
            case .dashboard, .smartScan:
                SmartScanScreen()
            case .cleanup:
                ScanScreen(module: .cleanup,
                           subtitle: L("Caches, journaux et fichiers temporaires : tout ce que votre Mac et vos apps recréent tout seuls. Supprimés définitivement, l'espace est libéré tout de suite."))
            case .uninstaller, .updates:
                ApplicationsScreen()
            case .files, .similarPhotos:
                FilesScreen()
            case .developer:
                ScanScreen(module: .developer,
                           subtitle: L("Libérez l'espace pris par Xcode, les caches de paquets, les node_modules oubliés, Homebrew et Docker. Les caches sont supprimés définitivement ; les commandes (brew, docker, simctl) se lancent depuis leur ligne."))
            case .spaceLens:
                SpaceLensScreen()
            case .security, .privacy:
                ProtectionScreen()
            case .performance, .maintenance:
                PerformanceScreen()
            case .history:
                HistoryScreen()
            case .result:
                ResultScreen()
            }
        }
        .background(LayoutProbe.reporter(\.contentWidth))
        // minWidth 0 + clip: a screen wider than the pane can never push the
        // sidebar out of the window (it used to be centered and cropped left).
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(LayoutProbe.reporter(\.paneWidth))
        .clipped()
    }
}
