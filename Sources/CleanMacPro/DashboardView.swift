import SwiftUI
import CleanCore

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            if let module = appState.selectedModule {
                ModuleDetail(module: module)
            } else {
                OverviewView()
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CleanMac Pro")
                    .font(.title2.weight(.bold))
                Text("v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            List(selection: $appState.selectedModule) {
                Section("Modules") {
                    ForEach(ModuleID.allCases) { module in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(module.title).font(.body)
                                Text(module.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: module.symbol)
                                .foregroundStyle(.tint)
                        }
                        .tag(module)
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

struct OverviewView: View {
    var body: some View {
        ContentUnavailableView(
            "Welcome to CleanMac Pro",
            systemImage: "sparkles",
            description: Text("Pick a module on the left to get started.")
        )
    }
}

struct ModuleDetail: View {
    @EnvironmentObject var appState: AppState
    let module: ModuleID

    var body: some View {
        let state = appState.state(for: module)
        VStack(alignment: .leading, spacing: 0) {
            ModuleHeader(module: module, state: state)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Divider().padding(.vertical, 16)

            if state.isScanning {
                ProgressPanel(state: state)
                    .padding(.horizontal, 24)
            } else if let result = state.result {
                ResultsList(module: module, result: result)
            } else {
                EmptyModuleView(module: module) {
                    appState.startScan(module: module)
                }
            }
        }
    }
}

struct ModuleHeader: View {
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    let state: ModuleState

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: module.symbol)
                        .font(.title)
                        .foregroundStyle(.tint)
                    Text(module.title).font(.largeTitle.weight(.bold))
                }
                Text(state.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if state.isScanning {
                Button(role: .cancel) {
                    appState.cancelScan(module: module)
                } label: {
                    Label("Cancel", systemImage: "stop.circle")
                }
                .controlSize(.large)
            } else if let result = state.result, !result.items.isEmpty {
                Button {
                    appState.clean(module: module)
                } label: {
                    Label(
                        "Clean \(state.selection.count > 0 ? "Selected" : "All") · \(ByteFormatter.string(selectedSize(state: state, result: result)))",
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedSize(state: state, result: result) == 0)
            } else {
                Button {
                    appState.startScan(module: module)
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func selectedSize(state: ModuleState, result: ScanResult) -> Int64 {
        if state.selection.isEmpty { return result.totalSize }
        return result.items.filter { state.selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }
}

struct ProgressPanel: View {
    let state: ModuleState
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: state.progress)
                .progressViewStyle(.linear)
            Text(state.status)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct EmptyModuleView: View {
    let module: ModuleID
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: module.symbol)
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text(module.title).font(.title2.weight(.semibold))
            Text(module.subtitle).foregroundStyle(.secondary)
            Button {
                onScan()
            } label: {
                Label("Start Scan", systemImage: "play.fill")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ResultsList: View {
    @EnvironmentObject var appState: AppState
    let module: ModuleID
    let result: ScanResult

    private var grouped: [(key: String, value: [ScanItem])] {
        Dictionary(grouping: result.items, by: { $0.group ?? "Other" })
            .map { ($0.key, $0.value.sorted { $0.size > $1.size }) }
            .sorted { sumSize($0.1) > sumSize($1.1) }
    }

    private func sumSize(_ items: [ScanItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.key) { group, items in
                Section {
                    ForEach(items) { item in
                        ItemRow(item: item, isSelected: appState.state(for: module).selection.contains(item.id)) {
                            toggle(item)
                        }
                    }
                } header: {
                    HStack {
                        Text(group).font(.headline)
                        Spacer()
                        Text("\(items.count) · \(ByteFormatter.string(sumSize(items)))")
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func toggle(_ item: ScanItem) {
        appState.update(module) { s in
            if s.selection.contains(item.id) { s.selection.remove(item.id) }
            else { s.selection.insert(item.id) }
        }
    }
}

struct ItemRow: View {
    let item: ScanItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body)
                Text(item.url.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormatter.string(item.size))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
