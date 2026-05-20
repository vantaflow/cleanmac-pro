import SwiftUI
import CleanCore

/// Big animated scan screen — runs Cleanup, Files, Security in parallel and
/// shows per-category progress with a hero ring.
struct SmartScanScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private let categories: [ModuleID] = [.cleanup, .files, .security, .updates, .privacy]

    private var aggregatedProgress: Double {
        let values = categories.map { appState.state(for: $0).progress }
        return values.reduce(0, +) / Double(max(values.count, 1))
    }
    private var anyScanning: Bool {
        categories.contains { appState.state(for: $0).isScanning }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(
                title: "Smart Scan",
                subtitle: "Analyse complète — caches, gros fichiers, sécurité, mises à jour, vie privée."
            ) {
                Btn(kind: .primary, size: .lg, icon: anyScanning ? "pause" : "scan",
                    label: anyScanning ? "Annuler" : "Tout scanner") {
                    if anyScanning {
                        categories.forEach { appState.cancelScan(module: $0) }
                    } else {
                        categories.forEach { appState.startScan(module: $0) }
                    }
                }
            }

            GlassPanel(radius: 16, padding: 24) {
                HStack(spacing: 32) {
                    Ring(size: 220, stroke: 14, value: aggregatedProgress * 100,
                         color: theme.accent.color) {
                        VStack(spacing: 0) {
                            Text("\(Int(aggregatedProgress * 100)) %")
                                .font(.system(size: 48, weight: .bold))
                                .tracking(-2)
                                .foregroundColor(.text1(theme.dark))
                            Text(anyScanning ? "en cours" : "prêt")
                                .font(.system(size: 12))
                                .foregroundColor(.text3(theme.dark))
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(categories, id: \.self) { module in
                            categoryRow(module: module)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .padding(.horizontal, 28)
    }

    private func categoryRow(module: ModuleID) -> some View {
        let state = appState.state(for: module)
        let count = state.result?.count ?? 0
        let label = state.isScanning ? state.status
                                     : (state.result == nil ? "En attente" : "\(count) éléments")
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme.accent.color.opacity(0.15))
                CmpIcon(name: module.symbol, size: 16, color: theme.accent.color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(module.title).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.text1(theme.dark))
                    Spacer()
                    Text("\(Int(state.progress * 100)) %")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.text3(theme.dark))
                }
                ProgressView(value: state.progress).tint(theme.accent.color)
                Text(label).font(.system(size: 11)).foregroundColor(.text3(theme.dark))
            }
        }
    }
}
