import SwiftUI
import CleanCore

/// "Nettoyage terminé": the space the volume really gained (free space measured
/// before and after), what was deleted for good vs sent to the Trash, and what
/// could not be removed.
struct ResultScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @State private var shown: Double = 0

    var body: some View {
        if let o = appState.lastOutcome {
            content(o)
        } else {
            EmptyState(symbol: "sparkles", title: L("Aucun nettoyage récent"),
                       message: L("Lancez une analyse Smart Care : le résultat, avec l'espace réellement libéré sur le disque, s'affichera ici."),
                       accent: .mint, actionLabel: L("Aller à Smart Care")) { appState.navigate(to: .smartScan) }
        }
    }

    private func content(_ o: CleanOutcome) -> some View {
        let dark = theme.dark
        let freed = o.measure.freedBytes
        return ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                    Text(L("Nettoyage terminé")).font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundColor(Accent.mint.onAccent)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Accent.mint.color))

                VStack(spacing: 8) {
                    CountUpBytes(value: shown, unitScale: freed)
                        .foregroundStyle(Accent.mint.color)
                    Text(freed > 0 ? L("libérés sur votre disque") : L("Aucun espace libéré sur le disque"))
                        .font(.system(size: 18)).foregroundColor(.text2(dark))
                    if let b = o.measure.before, let a = o.measure.after {
                        Text(L("Espace libre : \(ByteFormatter.string(b.freeBytes)) → \(ByteFormatter.string(a.freeBytes)) · mesuré sur \(DiskSpace.volumeName())"))
                            .font(.system(size: 13.5)).foregroundColor(.text3(dark))
                    }
                }
                .multilineTextAlignment(.center)

                notes(o)
                breakdown(o)

                HStack(spacing: 12) {
                    Btn(kind: .secondary, size: .lg, label: L("Voir l'historique")) { appState.navigate(to: .history) }
                    Btn(kind: .primary, size: .lg, label: L("Retour à Smart Care")) { appState.navigate(to: .smartScan) }
                        .accessibilityIdentifier("result-back")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 28).padding(.vertical, 36)
            .frame(maxWidth: .infinity)
        }
        .onAppear { animate(to: freed) }
        .onChange(of: freed) { v in animate(to: v) }
    }

    private func animate(to value: Int64) {
        shown = 0
        withAnimation(.easeOut(duration: 1.0)) { shown = Double(value) }
    }

    @ViewBuilder private func notes(_ o: CleanOutcome) -> some View {
        VStack(spacing: 10) {
            if o.report.trashedBytes > 0 {
                HStack(spacing: 12) {
                    Banner(symbol: "trash.fill",
                           text: L("\(ByteFormatter.string(o.report.trashedBytes)) sont dans la Corbeille : cet espace ne sera libéré que lorsque vous la viderez."),
                           accent: Accent.amber.color)
                    Btn(kind: .secondary, size: .md, label: L("Vider la Corbeille")) { appState.emptyTrash() }
                }
            }
            if o.measure.gainedLessThanReported {
                Banner(symbol: "info.circle.fill",
                       text: L("Le disque a gagné moins que prévu : des instantanés Time Machine ou des fichiers encore ouverts retiennent une partie de l'espace."),
                       accent: Accent.blue.color)
            }
            if !o.report.failedItems.isEmpty {
                Banner(symbol: "exclamationmark.triangle.fill",
                       text: L("\(o.report.failedItems.count) élément(s) n'ont pas pu être supprimés (protégés par macOS ou en cours d'utilisation)."),
                       accent: Accent.coral.color)
            }
            if o.updatesInstalled + o.updatesManual + o.updatesFailed > 0 {
                Banner(symbol: "arrow.down.circle.fill",
                       text: L("Mises à jour : \(o.updatesInstalled) installée(s), \(o.updatesManual) à faire à la main, \(o.updatesFailed) en échec."),
                       accent: Accent.violet.color)
            }
        }
    }

    @ViewBuilder private func breakdown(_ o: CleanOutcome) -> some View {
        if !o.rows.filter({ $0.report.removedCount > 0 }).isEmpty {
            let dark = theme.dark
            VStack(alignment: .leading, spacing: 0) {
                Text(L("DÉTAIL")).font(.system(size: 11, weight: .semibold)).tracking(0.9)
                    .foregroundColor(.text3(dark)).padding(.horizontal, 18).padding(.vertical, 12)
                ForEach(o.rows.filter { $0.report.removedCount > 0 }) { row in
                    Divider().overlay(Color.rowLine(dark))
                    HStack(spacing: 14) {
                        IconChip(symbol: row.module.railSymbol, accent: row.module.accentEnum, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.module.railTitle).font(.system(size: 14, weight: .semibold)).foregroundColor(.text1(dark))
                            Text(policyLine(row.report)).font(.system(size: 12)).foregroundColor(.text3(dark))
                        }
                        Spacer()
                        Text(ByteFormatter.string(row.report.freedBytes)).font(.figure(14)).foregroundColor(.text1(dark))
                    }
                    .padding(.horizontal, 18).padding(.vertical, 12)
                }
            }
            .cardSurface(dark: dark)
        }
    }

    private func policyLine(_ r: CleanReport) -> String {
        var parts: [String] = []
        if r.permanentCount > 0 { parts.append(L("\(r.permanentCount) supprimé(s) définitivement")) }
        if r.trashedCount > 0 { parts.append(L("\(r.trashedCount) envoyé(s) à la Corbeille")) }
        return parts.joined(separator: " · ")
    }
}

/// Big animated "4,7 Go": the number counts up to the measured value.
private struct CountUpBytes: View, Animatable {
    var value: Double
    var unitScale: Int64
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        let parts = Self.split(Int64(value.rounded()))
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(parts.0).font(.system(size: 92, weight: .bold).monospacedDigit()).tracking(-3)
            Text(parts.1).font(.system(size: 40, weight: .bold)).opacity(0.6)
        }
        .lineLimit(1).minimumScaleFactor(0.5)
    }

    /// ("4,7", "Go") from the localized byte formatter.
    static func split(_ bytes: Int64) -> (String, String) {
        let s = ByteFormatter.string(bytes)
        guard let i = s.lastIndex(where: { $0 == " " || $0 == "\u{00A0}" }) else { return (s, "") }
        return (String(s[..<i]), String(s[s.index(after: i)...]))
    }
}
