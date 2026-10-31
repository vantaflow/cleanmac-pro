import SwiftUI
import AppKit
import CleanCore

/// One entry of the left pane of the review screen.
struct ReviewCategory: Identifiable {
    let id: String
    let title: String
    let items: [ScanItem]

    var bytes: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectable: [ScanItem] { items.filter { $0.kind.isCleanable } }

    /// Short line under the title ("38 607 fichiers").
    var subtitle: String {
        let files = items.reduce(0) { $0 + ($1.fileCount ?? 1) }
        return files == 1 ? L("1 fichier") : L("\(files) fichiers")
    }

    /// What will happen to the selected rows of this category.
    var policyNote: String {
        let kinds = Set(items.map(\.kind))
        if kinds == [.trash] { return L("Vider la Corbeille supprime ces éléments définitivement. Cette action est irréversible.") }
        if kinds.contains(.privacyData) {
            return L("Envoyées à la Corbeille. Fermez d'abord le navigateur concerné pour que ses données soient bien libérées.")
        }
        if kinds.allSatisfy({ $0.deletionPolicy == .permanent }) {
            return L("Supprimés définitivement : chaque app les recrée au besoin. L'espace est libéré tout de suite.")
        }
        if kinds.allSatisfy({ $0.deletionPolicy == .trash }) {
            return L("Envoyés à la Corbeille : vous pouvez les restaurer depuis l'Historique tant qu'elle n'est pas vidée.")
        }
        return L("Les caches sont supprimés définitivement ; les autres éléments vont à la Corbeille.")
    }

    /// Categories shown for a module's result, in display order. Cache folders are
    /// already one row per app (see `CleanupScanner`); personal files are split
    /// into large / old / duplicates.
    static func build(module: ModuleID, items: [ScanItem]) -> [ReviewCategory] {
        let shown = items.filter { $0.kind != .keeper }
        switch module {
        case .cleanup:
            let order = [CleanupScanner.Group.appCaches, CleanupScanner.Group.temp, CleanupScanner.Group.logs,
                         CleanupScanner.Group.systemCaches, CleanupScanner.Group.trash]
            let by = Dictionary(grouping: shown, by: { $0.group ?? L("Autres") })
            let known = order.compactMap { g in by[g].map { ReviewCategory(id: g, title: g, items: $0) } }
            let rest = by.filter { !order.contains($0.key) }.map { ReviewCategory(id: $0.key, title: $0.key, items: $0.value) }
                .sorted { $0.bytes > $1.bytes }
            return known + rest
        case .files, .similarPhotos:
            let defs: [(ItemKind, String)] = [
                (.duplicate, module == .similarPhotos ? L("Photos similaires") : L("Doublons")),
                (.largeFile, L("Fichiers volumineux")),
                (.oldFile, L("Fichiers anciens")),
            ]
            return defs.compactMap { kind, title in
                let xs = shown.filter { $0.kind == kind }
                return xs.isEmpty ? nil : ReviewCategory(id: title, title: title, items: xs)
            }
        default:
            let by = Dictionary(grouping: shown, by: { $0.group ?? L("Autres") })
            return by.map { ReviewCategory(id: $0.key, title: $0.key, items: $0.value) }
                .sorted { $0.bytes > $1.bytes }
        }
    }
}

extension ModuleID {
    /// Modules whose results use the two-pane review layout.
    var usesReviewLayout: Bool {
        [.cleanup, .developer, .files, .similarPhotos, .privacy].contains(self)
    }
}

/// Two-pane review: categories on the left (tri-state checkbox, count, size),
/// rows grouped per app with real icons on the right, "Nettoyer X Go" below.
struct ReviewView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    let subtitle: String
    @State private var selectedCategory: String?

    private var state: ModuleState { appState.state(for: module) }

    var body: some View {
        let dark = theme.dark
        let items = state.result?.items ?? []
        let cats = ReviewCategory.build(module: module, items: appState.filter(items))
        let current = cats.first { $0.id == selectedCategory } ?? cats.first
        HStack(spacing: 0) {
            categoriesPane(cats, current: current)
            VStack(spacing: 0) {
                if let current {
                    listPane(current, all: cats)
                } else if !appState.searchText.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: L("Aucun résultat pour « \(appState.searchText) »"))
                } else {
                    EmptyState(symbol: "checkmark.circle", title: L("Rien à nettoyer ici"),
                               message: L("Cette analyse n'a rien trouvé à proposer. Relancez-la après avoir utilisé votre Mac."),
                               actionLabel: L("Relancer l'analyse")) { appState.startScan(module: module) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.canvas(dark))
    }

    // MARK: Left pane

    private func categoriesPane(_ cats: [ReviewCategory], current: ReviewCategory?) -> some View {
        let dark = theme.dark
        return VStack(alignment: .leading, spacing: 6) {
            if appState.cameFromSmartCare {
                Button { appState.backToSmartCare() } label: {
                    Text(L("← Résultats")).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.accent.soft)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.bottom, 8)
                .accessibilityIdentifier("review-back")
            }
            Text(module.railTitle)
                .font(.system(size: 11, weight: .semibold)).tracking(0.9)
                .foregroundColor(.text3(dark)).textCase(.uppercase)
                .padding(.horizontal, 10).padding(.bottom, 2)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(cats) { c in
                        CategoryButton(category: c, module: module, selected: c.id == current?.id) {
                            selectedCategory = c.id
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 14)
        .frame(width: 262)
        .background(Color.sidebarBg(dark).opacity(0.6))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.cardBorder(dark)).frame(width: 1) }
    }

    // MARK: Right pane

    private func listPane(_ cat: ReviewCategory, all: [ReviewCategory]) -> some View {
        let dark = theme.dark
        let sorted = cat.items.sorted(by: compare)
        let limit = 400
        let selection = state.selection
        let selectedItems = all.flatMap(\.items).filter { selection.contains($0.id) }
        let selectedBytes = selectedItems.reduce(0) { $0 + $1.size }
        let totalBytes = all.reduce(0) { $0 + $1.bytes }
        let keepers = Dictionary(
            (state.result?.items ?? []).filter { $0.kind == .keeper }.compactMap { k in k.group.map { ($0, k) } },
            uniquingKeysWith: { a, _ in a })
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cat.title).font(.system(size: 26, weight: .semibold)).tracking(-0.3)
                        .foregroundColor(.text1(dark))
                    Text(cat.policyNote).font(.system(size: 13.5)).foregroundColor(.text2(dark))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                SearchField()
                SortMenu(module: module)
            }
            .padding(.horizontal, 28).padding(.top, 26).padding(.bottom, 14)

            if state.lastMeasure != nil {
                Banner(symbol: "checkmark.circle.fill", text: state.status, accent: Accent.mint.color)
                    .padding(.horizontal, 24).padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sorted.prefix(limit)) { item in
                        ReviewRow(item: item, module: module, keeper: item.group.flatMap { keepers[keeperKey($0)] })
                        Divider().overlay(Color.rowLine(dark))
                    }
                    if sorted.count > limit {
                        Text(L("… et \(sorted.count - limit) autres, de plus petite taille. « Tout sélectionner » les inclut."))
                            .font(.system(size: 12.5)).foregroundColor(.text3(dark))
                            .padding(16)
                    }
                }
            }
            .cardSurface(dark: dark)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("results-listing-\(module.rawValue)")

            HStack(spacing: 12) {
                (Text(ByteFormatter.string(selectedBytes)).fontWeight(.semibold).foregroundColor(.text1(dark))
                 + Text(L(" sélectionnés sur \(ByteFormatter.string(totalBytes))")).foregroundColor(.text2(dark)))
                    .font(.system(size: 13.5))
                Spacer()
                Btn(kind: .secondary, size: .lg, label: L("Ne plus proposer…")) {
                    selectedItems.forEach { appState.exclude($0) }
                }
                .disabled(selectedItems.isEmpty || state.isCleaning)
                .help(L("Retire les éléments sélectionnés des prochaines analyses"))
                Btn(kind: .primary, size: .lg,
                    label: state.isCleaning ? L("Nettoyage…") : L("Nettoyer \(ByteFormatter.string(selectedBytes))")) {
                    appState.clean(module: module)
                }
                .disabled(selectedItems.isEmpty || state.isCleaning)
                .accessibilityIdentifier("review-clean-\(module.rawValue)")
            }
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 20)
        }
    }

    /// Duplicates are grouped "hash (dup)" / "hash (keep)"; photos share one label.
    private func keeperKey(_ group: String) -> String {
        group.hasSuffix("(dup)") ? String(group.dropLast(5)) + "(keep)" : group
    }

    private func compare(_ a: ScanItem, _ b: ScanItem) -> Bool {
        let asc = !state.sortDescending
        switch state.sortKey {
        case .size:     return asc ? a.size < b.size : a.size > b.size
        case .name:     return asc ? a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
                                   : a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedDescending
        case .modified: return asc ? a.modified < b.modified : a.modified > b.modified
        }
    }
}

private struct CategoryButton: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let category: ReviewCategory
    let module: ModuleID
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    private var ids: Set<UUID> { Set(category.selectable.map(\.id)) }
    private var chosen: Int { appState.state(for: module).selection.intersection(ids).count }

    var body: some View {
        let dark = theme.dark
        HStack(spacing: 10) {
            CmpCheckbox(isOn: Binding(
                get: { !ids.isEmpty && chosen == ids.count },
                set: { on in
                    appState.update(module) { s in
                        s.selection = on ? s.selection.union(ids) : s.selection.subtracting(ids)
                    }
                }), mixed: chosen > 0 && chosen < ids.count, label: category.title)
                .disabled(ids.isEmpty)
            Button(action: action) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title).font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.text1(dark)).lineLimit(1)
                        Text(category.subtitle).font(.system(size: 12)).foregroundColor(.text2(dark))
                    }
                    Spacer(minLength: 4)
                    Text(ByteFormatter.string(category.bytes))
                        .font(.figure(13)).foregroundColor(.textSoft(dark))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color.raised(dark) : (hover ? Color.raised(dark).opacity(0.5) : .clear)))
        .onHover { hover = $0 }
        .accessibilityIdentifier("category-\(category.id)")
    }
}

struct ReviewRow: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let item: ScanItem
    let module: ModuleID
    var keeper: ScanItem? = nil

    private var checked: Bool { appState.state(for: module).selection.contains(item.id) }

    var body: some View {
        let dark = theme.dark
        HStack(spacing: 14) {
            if item.kind.isCleanable {
                CmpCheckbox(isOn: Binding(get: { checked }, set: { _ in toggle() }), label: item.displayName)
            } else {
                Color.clear.frame(width: 18, height: 18)
            }
            FileIconView(path: item.iconPath, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.text1(dark)).lineLimit(1)
                Text(secondLine).font(.system(size: 12)).foregroundColor(.text3(dark))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let n = item.fileCount, n > 1 {
                Text(L("\(n) fichiers")).font(.system(size: 12)).foregroundColor(.text2(dark))
            }
            Text(ByteFormatter.string(item.size)).font(.figure(14))
                .foregroundColor(.text1(dark)).frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, 18).frame(height: 58)
        .contentShape(Rectangle())
        .onTapGesture { if item.kind.isCleanable { toggle() } }
        .contextMenu {
            Button(L("Afficher dans le Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button(L("Ne plus proposer ce chemin")) { appState.exclude(item) }
            if item.kind == .app { Button(L("Ne plus proposer cette app")) { appState.exclude(item, asApp: true) } }
        }
    }

    private var secondLine: String {
        if let keeper { return L("Même contenu que « \(keeper.name) » · \(item.prettyPath)") }
        return item.detail != nil && item.fileCount == nil ? (item.detail ?? "") : item.prettyPath
    }

    private func toggle() {
        appState.update(module) { s in
            if s.selection.contains(item.id) { s.selection.remove(item.id) } else { s.selection.insert(item.id) }
        }
    }
}

/// Live filter over the current listing.
struct SearchField: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.text3(theme.dark))
            TextField(L("Filtrer"), text: $appState.searchText)
                .textFieldStyle(.plain).font(.system(size: 13))
                .foregroundColor(.text1(theme.dark))
                .frame(width: 110)
            if !appState.searchText.isEmpty {
                Button { appState.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.text3(theme.dark))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).frame(height: 36)
        .background(Capsule().fill(Color.inset(theme.dark)))
        .overlay(Capsule().strokeBorder(Color.cardBorder(theme.dark), lineWidth: 1))
    }
}
