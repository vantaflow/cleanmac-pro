import SwiftUI
import CleanCore

/// Root layout: desktop wallpaper background → centered window → sidebar + main.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: appState.theme.wallpaper.stops,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView()
                MainPane()
            }
            .background(Color.windowBg(appState.theme.dark))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.45), radius: 40, y: 20)
            .padding(24)
        }
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
            if appState.active != .smartScan && appState.active != .result {
                QuickCleanFAB(action: { appState.active = .result })
                    .padding(28)
            }
        }
        .background(Color.windowBg(theme.dark))
    }
}
