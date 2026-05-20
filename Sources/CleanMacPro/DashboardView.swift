import SwiftUI
import CleanCore

/// Root layout: desktop wallpaper background → centered window → sidebar + main.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                SidebarView()
                MainPane()
            }
            .background(Color.windowBg(appState.theme.dark))
            .ignoresSafeArea()

            if appState.menubarOpen {
                MenubarWidget()
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if appState.showOnboarding {
                OnboardingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: appState.menubarOpen)
        .animation(.easeOut(duration: 0.35), value: appState.showOnboarding)
    }
}

private struct MainPane: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                AppToolbar()
                Group {
                    switch appState.active {
                    case .dashboard:
                        DashboardScreen()
                    case .smartScan:
                        SmartScanScreen()
                    case .cleanup:
                        ScanScreen(module: .cleanup,
                                   subtitle: "Caches, logs, corbeilles. Sans risque, restaurable depuis la Corbeille.")
                    case .uninstaller:
                        ScanScreen(module: .uninstaller,
                                   subtitle: "Désinstalle les apps et leurs résidus dans Library.")
                    case .files:
                        ScanScreen(module: .files,
                                   subtitle: "Gros fichiers et fichiers anciens dans Téléchargements, Documents, Bureau, Films.")
                    case .spaceLens:
                        SpaceLensScreen()
                    case .security:
                        ScanScreen(module: .security,
                                   subtitle: "FileVault, Gatekeeper, SIP, pare-feu, XProtect — état réel du système.",
                                   supportsClean: false)
                    case .privacy:
                        ScanScreen(module: .privacy,
                                   subtitle: "Données de navigation par navigateur. Sélectionne ce qui peut partir.")
                    case .updates:
                        ScanScreen(module: .updates,
                                   subtitle: "Homebrew + softwareupdate. Pas de mise à jour automatique — c'est toi qui décides.",
                                   supportsClean: false)
                    case .performance:
                        ScanScreen(module: .performance,
                                   subtitle: "Éléments de connexion, launch agents, top processus.",
                                   supportsClean: false)
                    case .maintenance:
                        ScanScreen(module: .maintenance,
                                   subtitle: "Tâches d'entretien — chaque action est documentée.",
                                   supportsClean: false)
                    case .result:
                        ResultScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if appState.active != .smartScan && appState.active != .result && !appState.showOnboarding {
                QuickCleanFAB(action: { appState.quickClean() })
                    .padding(28)
            }
        }
        .background(Color.windowBg(theme.dark))
    }
}
