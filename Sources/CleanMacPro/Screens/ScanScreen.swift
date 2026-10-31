import SwiftUI
import AppKit
import CleanCore

/// Generic scan-and-act screen used by every module: idle → scanning → results.
/// Modules that clean files (cleanup, developer, files, photos, privacy) show the
/// two-pane review; the others (security, performance, updates, maintenance,
/// uninstaller) show a grouped list with per-row actions.
struct ScanScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    var subtitle: String
    var primaryActionLabel: String = L("Nettoyer la sélection")
    var supportsClean: Bool = true
    /// Uninstaller: remove permanently (no Trash) so nothing lingers for other
    /// cleaners to detect.
    var permanentDelete: Bool = false

    var body: some View {
        let state = appState.state(for: module)
        Group {
            if state.isScanning {
                ModuleScanning(module: module, progress: state.progress, status: state.status) {
                    appState.cancelScan(module: module)
                }
            } else if state.result == nil {
                ModuleIdle(module: module, subtitle: subtitle) { appState.startScan(module: module) }
            } else if module.usesReviewLayout && supportsClean && !permanentDelete {
                ReviewView(module: module, subtitle: subtitle)
            } else {
                listBody(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: state.isScanning)
    }

    private func listBody(state: ModuleState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.cameFromSmartCare {
                Button { appState.backToSmartCare() } label: {
                    Text(L("← Résultats")).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.accent.soft)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28).padding(.top, 18)
                .accessibilityIdentifier("review-back")
            }
            ScreenHeader(title: module.title, subtitle: subtitle) {
                HStack(spacing: 10) {
                    if let result = state.result, !result.items.isEmpty {
                        SortMenu(module: module)
                    }
                    if let result = state.result, !result.items.isEmpty, supportsClean {
                        let selected = state.selection.count
                        Btn(kind: .primary, size: .lg, icon: "trash",
                            label: state.isCleaning ? L("Nettoyage…")
                                 : (selected == 0 ? L("Tout sélectionner") : "\(primaryActionLabel) (\(selected))")) {
                            if selected == 0 {
                                appState.update(module) { s in
                                    s.selection = Set(result.items.filter { $0.kind.isCleanable }.map(\.id))
                                }
                            } else {
                                appState.clean(module: module, permanent: permanentDelete)
                            }
                        }
                        .disabled(state.isCleaning)
                    }
                    Btn(kind: .secondary, size: .lg, icon: "arrow.clockwise", label: L("Relancer")) {
                        appState.startScan(module: module)
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, appState.cameFromSmartCare ? 8 : 24)

            if state.lastMeasure != nil {
                Banner(symbol: "checkmark.circle.fill", text: state.status, accent: Accent.mint.color)
                    .padding(.horizontal, 28).padding(.bottom, 12)
            }

            if let result = state.result {
                if result.items.isEmpty {
                    EmptyState(symbol: "checkmark.circle", title: L("Rien à signaler"),
                               message: L("Cette analyse n'a rien trouvé à proposer."),
                               actionLabel: L("Relancer l'analyse")) { appState.startScan(module: module) }
                } else {
                    ResultsListing(module: module, result: result)
                }
            }
        }
    }
}

// MARK: — Idle / scanning

struct ModuleIdle: View {
    @Environment(\.theme) private var theme
    let module: ModuleID
    var subtitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            HeroRing(symbol: module.railSymbol, accent: module.accentEnum, size: 200)
            VStack(spacing: 10) {
                Text(module.railTitle)
                    .font(.system(size: 36, weight: .semibold)).tracking(-0.7)
                    .foregroundColor(.text1(theme.dark))
                Text(subtitle)
                    .font(.system(size: 15.5)).lineSpacing(3)
                    .foregroundColor(.text2(theme.dark))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
            Btn(kind: .primary, size: .xl, label: L("Analyser"), action: action)
                .accessibilityIdentifier("module-analyze-\(module.rawValue)")
        }
        .padding(40)
    }
}

struct ModuleScanning: View {
    @Environment(\.theme) private var theme
    let module: ModuleID
    let progress: Double
    let status: String
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HeroRing(symbol: module.railSymbol, accent: module.accentEnum, progress: progress, size: 200)
            VStack(spacing: 8) {
                Text(L("Analyse en cours…"))
                    .font(.system(size: 30, weight: .semibold)).foregroundColor(.text1(theme.dark))
                Text(verbatim: "\(Int(progress * 100)) %")
                    .font(.figure(16)).foregroundColor(.text2(theme.dark))
                Text(status).font(.system(size: 13)).foregroundColor(.text3(theme.dark))
                    .lineLimit(1).truncationMode(.middle).frame(maxWidth: 480)
            }
            Btn(kind: .secondary, size: .lg, label: L("Annuler"), action: cancel)
        }
        .padding(40)
    }
}

// MARK: — Grouped listing (security, performance, updates, maintenance, uninstaller)

private struct ResultsListing: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    let result: ScanResult

    private func compare(_ a: ScanItem, _ b: ScanItem) -> Bool {
        let s = appState.state(for: module)
        let asc = !s.sortDescending
        switch s.sortKey {
        case .size:     return asc ? a.size < b.size : a.size > b.size
        case .name:     return asc ? a.name < b.name : a.name > b.name
        case .modified: return asc ? a.modified < b.modified : a.modified > b.modified
        }
    }
    private func compareGroups(_ a: (String, [ScanItem]), _ b: (String, [ScanItem])) -> Bool {
        let s = appState.state(for: module)
        let asc = !s.sortDescending
        switch s.sortKey {
        case .size:
            let sa = a.1.reduce(0) { $0 + $1.size }, sb = b.1.reduce(0) { $0 + $1.size }
            return asc ? sa < sb : sa > sb
        case .name:
            return asc ? a.0 < b.0 : a.0 > b.0
        case .modified:
            let ma = a.1.map(\.modified).max() ?? .distantPast
            let mb = b.1.map(\.modified).max() ?? .distantPast
            return asc ? ma < mb : ma > mb
        }
    }
    private var visibleItems: [ScanItem] { appState.filter(result.items) }
    private var grouped: [(String, [ScanItem])] {
        Dictionary(grouping: visibleItems, by: { $0.group ?? L("Autres") })
            .map { ($0.key, $0.value.sorted(by: compare)) }
            .sorted(by: compareGroups)
    }

    var body: some View {
        let dark = theme.dark
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(grouped, id: \.0) { group, items in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group).font(.system(size: 13, weight: .semibold)).foregroundColor(.text1(dark))
                            Spacer()
                            let total = items.reduce(0) { $0 + $1.size }
                            Text(total > 0 ? "\(items.count) · \(ByteFormatter.string(total))" : "\(items.count)")
                                .font(.figure(12, .medium)).foregroundColor(.text2(dark))
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(items.prefix(80)) { item in
                                ItemRow(item: item, module: module)
                                if item.id != items.prefix(80).last?.id {
                                    Divider().overlay(Color.rowLine(dark))
                                }
                            }
                        }
                        .cardSurface(dark: dark)
                    }
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 32)
        }
        .accessibilityIdentifier("results-listing-\(module.rawValue)")
    }
}

private struct ItemRow: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let item: ScanItem
    let module: ModuleID

    private var selectable: Bool { item.kind.isCleanable }
    private var isRunnable: Bool {
        item.command != nil &&
        [.maintenanceTask, .loginItem, .launchAgent, .updateAvailable].contains(item.kind)
    }
    private var runLabel: String {
        switch item.kind {
        case .loginItem:        return item.needsAdmin ? L("Désactiver (admin)") : L("Désactiver")
        case .launchAgent:      return item.needsAdmin ? L("Décharger (admin)") : L("Décharger")
        case .updateAvailable:  return L("Mettre à jour")
        case .maintenanceTask:  return item.needsAdmin ? L("Exécuter (admin)") : L("Exécuter")
        default:                return L("Exécuter")
        }
    }
    private var checked: Bool { appState.state(for: module).selection.contains(item.id) }
    private var tone: Color {
        switch item.severity {
        case .good: return .cmpGood
        case .warn: return .cmpWarn
        case .bad:  return .cmpBad
        case .info: return theme.accent.color
        }
    }
    /// Apps and their residues show their real icon.
    private var hasRealIcon: Bool {
        (item.kind == .app || item.kind == .appResidue || (item.kind == .updateAvailable && item.url.pathExtension == "app"))
            && FileManager.default.fileExists(atPath: item.url.path)
    }

    var body: some View {
        let dark = theme.dark
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                if selectable {
                    CmpCheckbox(isOn: Binding(get: { checked }, set: { _ in toggle() }), label: item.name)
                } else {
                    Circle().fill(tone).frame(width: 8, height: 8).padding(.horizontal, 5)
                }
                if hasRealIcon {
                    FileIconView(path: item.url.path, size: 30)
                } else {
                    IconChip(symbol: symbol, accent: chipAccent, size: 30)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.text1(dark)).lineLimit(1)
                    if let detail = item.detail {
                        Text(detail).font(.system(size: 12)).foregroundColor(.text3(dark))
                            .lineLimit(1).truncationMode(.middle)
                    } else if item.url.path.count > 1 {
                        Text(item.prettyPath).font(.system(size: 12)).foregroundColor(.text3(dark))
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                if item.size > 0 {
                    Text(ByteFormatter.string(item.size)).font(.figure(13)).foregroundColor(.text1(dark))
                } else {
                    severityLabel
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if selectable { toggle() } }

            if isRunnable {
                Btn(kind: .secondary, size: .sm,
                    icon: item.needsAdmin ? "lock" : "play", label: runLabel) {
                    if item.sparkleRelease != nil { appState.installSparkleUpdate(item: item) }
                    else { appState.runMaintenance(item: item, module: module) }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contextMenu {
            Button(L("Ne plus proposer ce chemin")) { appState.exclude(item) }
            if item.kind == .app {
                Button(L("Ne plus proposer cette app")) { appState.exclude(item, asApp: true) }
            }
        }
    }

    private func toggle() {
        appState.update(module) { s in
            if s.selection.contains(item.id) { s.selection.remove(item.id) } else { s.selection.insert(item.id) }
        }
    }

    private var chipAccent: Accent {
        switch item.severity {
        case .good: return .mint
        case .warn: return .amber
        case .bad:  return .coral
        case .info: return module.accentEnum
        }
    }

    private var symbol: String {
        switch item.kind {
        case .cache, .log, .trash, .tempFile: return "sparkles"
        case .largeFile, .oldFile, .duplicate: return "doc.fill"
        case .app:                             return "square.grid.2x2.fill"
        case .appResidue:                      return "trash.fill"
        case .securityFinding:                 return "shield.lefthalf.filled"
        case .updateAvailable:                 return "arrow.down.circle.fill"
        case .loginItem, .launchAgent:         return "bolt.fill"
        case .processSnapshot:                 return "memorychip"
        case .privacyData:                     return "eye.fill"
        case .maintenanceTask:                 return "wrench.and.screwdriver.fill"
        case .spaceFolder:                     return "folder.fill"
        case .keeper:                          return "checkmark"
        }
    }

    private var severityLabel: some View {
        let text: String
        switch item.severity {
        case .good: text = L("OK")
        case .warn: text = L("Attention")
        case .bad:  text = L("Critique")
        case .info: text = L("Info")
        }
        return StatusPill(status: pillStatus, text: text)
    }
    private var pillStatus: PillStatus {
        switch item.severity {
        case .good: return .good
        case .warn: return .warn
        case .bad:  return .bad
        case .info: return .info
        }
    }
}
