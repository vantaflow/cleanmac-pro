import SwiftUI
import CleanCore

/// Immersive CleanMyMac 5-style shell: a per-module colored gradient fills the
/// whole window, a translucent labeled sidebar sits on the left, and the active
/// module's screen renders directly on the gradient.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                IconRail()
                ContentPane()
            }
            .moduleBackground(appState.active.theme)

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
        .animation(.easeInOut(duration: 0.35), value: appState.active)
    }
}

/// Hosts the active module's screen, directly on the gradient.
private struct ContentPane: View {
    @EnvironmentObject var appState: AppState

    private var themed: Theme {
        var t = appState.theme
        t.accent = appState.active.accentEnum
        return t
    }

    var body: some View {
        content
            .environment(\.theme, themed)
    }

    private var content: some View {
        Group {
            switch appState.active {
            case .dashboard, .smartScan:
                SmartScanScreen()
            case .cleanup:
                ScanScreen(module: .cleanup,
                           subtitle: "Nettoyez votre système pour profiter de performances optimales et récupérer de l'espace disque.")
            case .uninstaller:
                ApplicationsScreen()
            case .files:
                ScanScreen(module: .files,
                           subtitle: "Examinez votre espace de stockage pour supprimer les fichiers dont vous n'avez pas besoin et désencombrer votre disque.")
            case .spaceLens:
                SpaceLensScreen()
            case .security:
                ProtectionScreen()
            case .privacy:
                ScanScreen(module: .privacy,
                           subtitle: "Données de navigation par navigateur. Sélectionne ce qui peut partir.")
            case .updates:
                ScanScreen(module: .updates,
                           subtitle: "Homebrew + softwareupdate. Pas de mise à jour automatique — c'est toi qui décides.",
                           supportsClean: false)
            case .performance:
                PerformanceScreen()
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
}
