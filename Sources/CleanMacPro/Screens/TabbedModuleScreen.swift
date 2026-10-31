import SwiftUI
import CleanCore

/// A CleanMyMac 5 module that groups several scanners under one identity with a
/// segmented tab bar (e.g. Applications = Désinstaller + Mises à jour).
struct TabbedModuleScreen: View {
    struct Tab: Identifiable {
        let id = UUID()
        let module: ModuleID
        let label: String
        let subtitle: String
        var supportsClean: Bool = true
        var permanentDelete: Bool = false
    }

    let tabs: [Tab]
    @State private var sel = 0
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            SegmentedTabs(labels: tabs.map(\.label), selection: $sel,
                          accent: appState.active.theme.accent)
                .padding(.top, 18)
                .padding(.bottom, 4)

            let t = tabs[min(sel, tabs.count - 1)]
            ScanScreen(module: t.module,
                       subtitle: t.subtitle,
                       supportsClean: t.supportsClean,
                       permanentDelete: t.permanentDelete)
                .id(t.id)
        }
    }
}

private struct SegmentedTabs: View {
    let labels: [String]
    @Binding var selection: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                Button {
                    selection = i
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selection == i ? .white : .white.opacity(0.7))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(
                            Capsule().fill(selection == i ? Color.white.opacity(0.20) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.22)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
    }
}

// MARK: — CleanMyMac 5 grouped modules

struct ApplicationsScreen: View {
    var body: some View {
        TabbedModuleScreen(tabs: [
            .init(module: .uninstaller,
                  label: L("Désinstalleur"),
                  subtitle: L("Prenez le contrôle de vos applications. Désinstallez-les complètement, résidus compris — suppression définitive, indétectable par les autres nettoyeurs."),
                  supportsClean: true, permanentDelete: true),
            .init(module: .updates,
                  label: L("Mises à jour"),
                  subtitle: L("Applications obsolètes détectées via Homebrew et l'App Store. Pas de mise à jour automatique — c'est vous qui décidez."),
                  supportsClean: false)
        ])
    }
}

struct ProtectionScreen: View {
    var body: some View {
        TabbedModuleScreen(tabs: [
            .init(module: .security,
                  label: L("Analyse"),
                  subtitle: L("Analysez votre Mac pour détecter toutes sortes de menaces et de failles. FileVault, Gatekeeper, SIP, pare-feu, XProtect."),
                  supportsClean: false),
            .init(module: .privacy,
                  label: L("Confidentialité"),
                  subtitle: L("Données de navigation par navigateur. Sélectionnez ce qui peut partir."),
                  supportsClean: true)
        ])
    }
}

struct PerformanceScreen: View {
    var body: some View {
        TabbedModuleScreen(tabs: [
            .init(module: .performance,
                  label: L("Optimisation"),
                  subtitle: L("Exécutez les tâches d'entretien recommandées pour optimiser les performances de votre Mac."),
                  supportsClean: false),
            .init(module: .maintenance,
                  label: L("Maintenance"),
                  subtitle: L("Tâches d'entretien — chaque action est documentée."),
                  supportsClean: false)
        ])
        // Login items need System Events: ask only now that the user opened Performances.
        .onAppear { if !UITestDriver.isEnabled { PermissionCenter.shared.requestAutomationIfNeeded() } }
    }
}

struct FilesScreen: View {
    var body: some View {
        TabbedModuleScreen(tabs: [
            .init(module: .files,
                  label: L("Volumineux & doublons"),
                  subtitle: L("Examinez votre espace de stockage pour supprimer les fichiers dont vous n'avez pas besoin et désencombrer votre disque.")),
            .init(module: .similarPhotos,
                  label: L("Photos similaires"),
                  subtitle: L("Retrouve les photos quasi identiques (recadrées, redimensionnées, recompressées) dans Images, Téléchargements et Bureau. La meilleure de chaque groupe est conservée ; les autres vont à la Corbeille."))
        ])
    }
}
