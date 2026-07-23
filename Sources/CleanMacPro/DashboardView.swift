import SwiftUI
import CleanCore

/// Immersive CleanMyMac 5-style shell: full-bleed gradient, icon rail on the
/// left, a frosted content card, and a centered floating title bar.
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Full-bleed immersive gradient.
            theme.wallpaper.immersiveGradient
                .overlay(
                    // soft top-center highlight
                    RadialGradient(colors: [Color.white.opacity(0.12), .clear],
                                   center: .init(x: 0.5, y: -0.1),
                                   startRadius: 0, endRadius: 700)
                )
                .ignoresSafeArea()

            HStack(spacing: 0) {
                IconRail()
                ContentPane()
                    .padding(.trailing, 14)
                    .padding(.vertical, 14)
            }

            // Centered floating title (window is chromeless).
            Text(appState.active.railTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .frame(height: 30)
                .padding(.top, 14)

            if appState.menubarOpen {
                MenubarWidget()
                    .padding(.top, 40)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if appState.showOnboarding {
                OnboardingOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.22), value: appState.menubarOpen)
        .animation(.easeOut(duration: 0.35), value: appState.showOnboarding)
        .animation(.easeOut(duration: 0.28), value: appState.active)
    }
}

/// The frosted card that hosts the active module's screen.
private struct ContentPane: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                switch appState.active {
                case .dashboard, .smartScan:
                    SmartScanScreen()
                case .cleanup:
                    ScanScreen(module: .cleanup,
                               subtitle: "Caches, logs, corbeilles. Sans risque, restaurable depuis la Corbeille.")
                case .uninstaller:
                    ScanScreen(module: .uninstaller,
                               subtitle: "Désinstalle les apps et leurs résidus. Suppression définitive (pas la corbeille) — indétectable par les autres nettoyeurs.",
                               permanentDelete: true)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .immersiveCard(radius: 28)
    }
}
