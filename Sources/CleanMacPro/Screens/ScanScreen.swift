import SwiftUI
import CleanCore

/// Generic scan-and-clean screen used by cleanup, files, uninstaller, privacy,
/// performance, security, updates, maintenance. Each module just supplies its
/// own header copy + which actions it supports.
struct ScanScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    var subtitle: String
    var primaryActionLabel: String = "Nettoyer la sélection"
    var supportsClean: Bool = true

    var body: some View {
        let state = appState.state(for: module)
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: module.title, subtitle: subtitle) {
                HStack(spacing: 8) {
                    if state.result != nil && !(state.result?.items.isEmpty ?? true) {
                        SortMenu(module: module)
                    }
                    if state.isScanning {
                        Btn(kind: .secondary, icon: "pause", label: "Annuler") {
                            appState.cancelScan(module: module)
                        }
                    } else if let result = state.result, !result.items.isEmpty, supportsClean {
                        let selected = state.selection.count
                        Btn(kind: .primary, size: .lg, icon: "trash",
                            label: selected == 0 ? "Tout sélectionner" : "\(primaryActionLabel) (\(selected))") {
                            if selected == 0 {
                                appState.update(module) { s in
                                    s.selection = Set(result.items.map(\.id))
                                }
                            } else {
                                appState.clean(module: module)
                            }
                        }
                    } else {
                        Btn(kind: .primary, size: .lg, icon: "scan", label: "Lancer un scan") {
                            appState.startScan(module: module)
                        }
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, 20)

            if state.isScanning {
                ScanningView(progress: state.progress, status: state.status)
                    .padding(.horizontal, 28).padding(.bottom, 28)
            } else if let result = state.result {
                if result.items.isEmpty {
                    EmptyResultsView(message: "Aucun élément à signaler.")
                } else {
                    ResultsListing(module: module, result: result)
                }
            } else {
                EmptyScanView(module: module) {
                    appState.startScan(module: module)
                }
            }
        }
    }
}

private struct ScanningView: View {
    @Environment(\.theme) private var theme
    let progress: Double
    let status: String

    var body: some View {
        GlassPanel(radius: 14, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    CmpIcon(name: "scan", size: 18, color: theme.accent.color)
                    Text("Scan en cours")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.text1(theme.dark))
                    Spacer()
                    Text("\(Int(progress * 100)) %")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.text2(theme.dark))
                }
                ProgressView(value: progress).tint(theme.accent.color)
                Text(status).font(.system(size: 12)).foregroundColor(.text3(theme.dark))
            }
        }
    }
}

private struct EmptyScanView: View {
    @Environment(\.theme) private var theme
    let module: ModuleID
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            CmpIcon(name: module.symbol, size: 56, color: .text3(theme.dark))
            Text(module.title).font(.system(size: 18, weight: .semibold))
                .foregroundColor(.text1(theme.dark))
            Text(module.subtitle).foregroundColor(.text2(theme.dark))
            Btn(kind: .primary, size: .lg, icon: "play", label: "Lancer", action: action)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EmptyResultsView: View {
    @Environment(\.theme) private var theme
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            CmpIcon(name: "check", size: 40, color: .cmpGood)
            Text(message).font(.system(size: 14)).foregroundColor(.text2(theme.dark))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

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
    private var grouped: [(String, [ScanItem])] {
        let dict = Dictionary(grouping: result.items, by: { $0.group ?? "Autres" })
        return dict
            .map { ($0.key, $0.value.sorted(by: compare)) }
            .sorted { $0.1.reduce(0) { $0 + $1.size } > $1.1.reduce(0) { $0 + $1.size } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(grouped, id: \.0) { group, items in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.text1(theme.dark))
                            Spacer()
                            Text("\(items.count) · \(ByteFormatter.string(items.reduce(0) { $0 + $1.size }))")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.text2(theme.dark))
                        }
                        .padding(.horizontal, 4)

                        GlassPanel(radius: 12, padding: 4) {
                            VStack(spacing: 0) {
                                ForEach(items.prefix(80)) { item in
                                    ItemRow(item: item, module: module)
                                    if item.id != items.prefix(80).last?.id {
                                        Divider().background(Color.hairlineSoft(theme.dark)).padding(.leading, 56)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 80)
        }
    }
}

private struct ItemRow: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let item: ScanItem
    let module: ModuleID

    private var selectable: Bool {
        ![.securityFinding, .maintenanceTask, .updateAvailable,
          .processSnapshot, .spaceFolder].contains(item.kind)
    }
    private var checked: Bool { appState.state(for: module).selection.contains(item.id) }
    private var color: Color {
        switch item.severity {
        case .good: return .cmpGood
        case .warn: return .cmpWarn
        case .bad:  return .cmpBad
        case .info: return theme.accent.color
        }
    }

    var body: some View {
        Button {
            if selectable {
                appState.update(module) { s in
                    if s.selection.contains(item.id) { s.selection.remove(item.id) }
                    else { s.selection.insert(item.id) }
                }
            }
        } label: {
            HStack(spacing: 12) {
                if selectable {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(checked ? theme.accent.color : Color.text3(theme.dark), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(checked ? theme.accent.color : Color.clear)
                            )
                        if checked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.accent.onAccent)
                        }
                    }
                    .frame(width: 18, height: 18)
                } else {
                    Circle().fill(color).frame(width: 8, height: 8).padding(.horizontal, 5)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.16))
                    CmpIcon(name: iconForKind, size: 14, color: color)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.text1(theme.dark))
                        .lineLimit(1)
                    if let detail = item.detail {
                        Text(detail).font(.system(size: 11))
                            .foregroundColor(.text3(theme.dark))
                            .lineLimit(1).truncationMode(.middle)
                    } else if item.url.path.count > 1 {
                        Text(item.url.path).font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.text3(theme.dark))
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer()
                if item.size > 0 {
                    Text(ByteFormatter.string(item.size))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.text1(theme.dark))
                } else {
                    severityLabel
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var iconForKind: String {
        switch item.kind {
        case .cache, .log, .trash, .tempFile: return "broom"
        case .largeFile, .oldFile, .duplicate: return "files"
        case .app:                             return "app"
        case .appResidue:                      return "trash"
        case .securityFinding:                 return "shield"
        case .updateAvailable:                 return "arrow"
        case .loginItem, .launchAgent:         return "bolt"
        case .processSnapshot:                 return "ram"
        case .privacyData:                     return "eye"
        case .maintenanceTask:                 return "wrench"
        case .spaceFolder:                     return "folder"
        }
    }

    private var severityLabel: some View {
        let text: String
        switch item.severity {
        case .good: text = "OK"
        case .warn: text = "Attention"
        case .bad:  text = "Critique"
        case .info: text = "Info"
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
