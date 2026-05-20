import SwiftUI
import CleanCore

struct ResultScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private var freedBytes: Int64 {
        appState.moduleStates.values.compactMap { $0.lastReport?.freedBytes }.reduce(0, +)
    }
    private var freedCount: Int {
        appState.moduleStates.values.compactMap { $0.lastReport?.removedCount }.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer().frame(height: 28)
                ZStack {
                    Circle().fill(theme.accent.color.opacity(0.15)).frame(width: 140, height: 140)
                    CmpIcon(name: "sparkle", size: 64, color: theme.accent.color)
                }

                Text(headline)
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1)
                    .foregroundColor(.text1(theme.dark))
                    .multilineTextAlignment(.center)

                Text(subline)
                    .font(.system(size: 15))
                    .foregroundColor(.text2(theme.dark))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Btn(kind: .secondary, icon: "dashboard", label: "Vue d'ensemble") {
                        appState.active = .dashboard
                    }
                    Btn(kind: .primary, size: .lg, icon: "scan", label: "Relancer un Smart Scan") {
                        appState.active = .smartScan
                    }
                }

                if freedBytes > 0 {
                    GlassPanel(radius: 12, padding: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CE QUI A ÉTÉ FAIT").font(.system(size: 10, weight: .semibold))
                                .tracking(0.8).foregroundColor(.text3(theme.dark))
                            ForEach(Array(appState.moduleStates.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { mod in
                                if let report = appState.moduleStates[mod]?.lastReport,
                                   report.removedCount > 0 {
                                    HStack {
                                        CmpIcon(name: mod.symbol, size: 14, color: theme.accent.color)
                                        Text(mod.title).font(.system(size: 13))
                                            .foregroundColor(.text1(theme.dark))
                                        Spacer()
                                        Text("\(report.removedCount) · \(ByteFormatter.string(report.freedBytes))")
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.text2(theme.dark))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                }
                Spacer().frame(height: 80)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
        }
    }

    private var headline: String {
        if freedBytes == 0 { return "Tout est en ordre." }
        return "Boom. \(ByteFormatter.string(freedBytes)) récupérés."
    }
    private var subline: String {
        if freedBytes == 0 { return "Aucun nettoyage récent. Lance un scan pour récupérer de l'espace." }
        return "\(freedCount) éléments envoyés à la Corbeille. Restaurables en un clic."
    }
}
