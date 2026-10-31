import SwiftUI
import CleanCore

/// Past cleanups. "Restaurer" exists only for what went to the Trash; what was
/// deleted for good (caches, logs, temp files, emptied Trash) is labelled as such.
struct HistoryScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @State private var message: String?

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.languageCode)
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private func module(_ raw: String) -> ModuleID { ModuleID(rawValue: raw) ?? .cleanup }

    var body: some View {
        let dark = theme.dark
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(kicker: L("\(ByteFormatter.string(appState.history.totalFreedBytes)) libérés au total"),
                         title: L("Historique"),
                         subtitle: L("Chaque nettoyage est consigné. Les éléments envoyés à la Corbeille peuvent être restaurés tant qu'elle n'est pas vidée ; le reste a été supprimé définitivement.")) {
                Btn(kind: .secondary, size: .lg, label: L("Effacer l'historique")) { appState.clearHistory() }
                    .disabled(appState.history.entries.isEmpty)
            }
            .padding(.horizontal, 28).padding(.top, 28)

            if let message {
                Banner(symbol: "arrow.uturn.backward.circle.fill", text: message, accent: Accent.slate.color)
                    .padding(.horizontal, 28).padding(.bottom, 12)
            }

            if appState.history.entries.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: L("Aucun nettoyage enregistré"),
                           message: L("Dès que vous aurez nettoyé quelque chose, il apparaîtra ici avec ce qui a été libéré."),
                           accent: .slate, actionLabel: L("Aller à Smart Care")) { appState.navigate(to: .smartScan) }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.history.entries) { e in
                            row(e)
                            if e.id != appState.history.entries.last?.id {
                                Divider().overlay(Color.rowLine(dark))
                            }
                        }
                    }
                    .cardSurface(dark: dark)
                    .padding(.horizontal, 28).padding(.bottom, 32)
                }
                .accessibilityIdentifier("history-list")
            }
        }
    }

    private func policy(_ e: HistoryEntry) -> String {
        var parts: [String] = []
        if e.permanentCount > 0 { parts.append(L("\(Int(e.permanentCount)) supprimé(s) définitivement")) }
        let t = e.itemCount - e.permanentCount
        if t > 0 { parts.append(L("\(Int(t)) dans la Corbeille")) }
        return parts.joined(separator: " · ")
    }

    private func row(_ e: HistoryEntry) -> some View {
        let dark = theme.dark
        let m = module(e.module)
        return HStack(spacing: 14) {
            IconChip(symbol: m.railSymbol, accent: m.accentEnum, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.railTitle).font(.system(size: 14.5, weight: .semibold)).foregroundColor(.text1(dark))
                Text(L("\(Self.dateFormat.string(from: e.date)) · \(policy(e))"))
                    .font(.system(size: 12.5)).foregroundColor(.text3(dark))
            }
            Spacer()
            Text(ByteFormatter.string(e.freedBytes)).font(.figure(14)).foregroundColor(.text1(dark))
            if e.canRestore {
                Btn(kind: .secondary, size: .sm, icon: "arrow.uturn.backward", label: L("Restaurer")) {
                    message = appState.restore(e).message
                }
            } else {
                Text(L("Définitif")).font(.system(size: 12, weight: .medium)).foregroundColor(.text3(dark))
                    .frame(width: 80, alignment: .trailing)
            }
            Button { appState.removeHistoryEntry(e) } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundColor(.text3(dark))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(L("Retirer de l'historique"))
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .contextMenu { Button(L("Supprimer de l'historique")) { appState.removeHistoryEntry(e) } }
    }
}
