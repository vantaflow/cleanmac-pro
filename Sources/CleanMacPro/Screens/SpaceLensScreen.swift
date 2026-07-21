import SwiftUI
import CleanCore

/// Faithful port of the design: hierarchical treemap with breadcrumb,
/// drill-down on click, side legend with hover sync.
struct SpaceLensScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @State private var pathStack: [URL] = []  // empty = current scan root
    @State private var hoveredID: UUID? = nil
    @State private var levelCache: [String: [ScanItem]] = [:]  // key = url.path
    @State private var loadingLevel = false

    /// Items for the level currently shown (root result, or drilled children).
    private var currentItems: [ScanItem] {
        guard let here = pathStack.last else {
            return appState.state(for: .spaceLens).result?.items ?? []
        }
        return levelCache[here.path] ?? []
    }

    var body: some View {
        let state = appState.state(for: .spaceLens)
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(
                kicker: "Space Lens",
                title: "Où vont tes Go.",
                subtitle: "Carte du disque en taille réelle. Survol → détail. Clic → explore le dossier."
            ) {
                if state.isScanning {
                    Btn(kind: .secondary, icon: "pause", label: "Annuler") {
                        appState.cancelScan(module: .spaceLens)
                    }
                } else if state.result == nil || (state.result?.items.isEmpty ?? true) {
                    Btn(kind: .primary, size: .lg, icon: "scan", label: "Scanner mon disque") {
                        appState.startScan(module: .spaceLens)
                    }
                } else {
                    Btn(kind: .secondary, icon: "scan", label: "Re-scanner") {
                        appState.startScan(module: .spaceLens)
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, 20)

            if state.isScanning {
                GlassPanel(radius: 14, padding: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Indexation \(state.status)").font(.system(size: 13))
                            .foregroundColor(.text2(theme.dark))
                        ProgressView(value: state.progress).tint(theme.accent.color)
                    }
                }
                .padding(.horizontal, 28)
            } else if let result = state.result, !result.items.isEmpty {
                content(items: currentItems.isEmpty && pathStack.isEmpty ? result.items : currentItems)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            CmpIcon(name: "disk", size: 56, color: .text3(theme.dark))
            Text("Lance un scan pour cartographier ton disque")
                .font(.system(size: 14)).foregroundColor(.text2(theme.dark))
            Text("Le scan utilise `du` — quelques secondes pour ton dossier utilisateur.")
                .font(.system(size: 12)).foregroundColor(.text3(theme.dark))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func content(items: [ScanItem]) -> some View {
        let total = items.reduce(0) { $0 + $1.size }
        return VStack(spacing: 12) {
            // Breadcrumb
            HStack(spacing: 6) {
                breadcrumbButton(label: "Macintosh HD", isLast: pathStack.isEmpty) {
                    pathStack = []
                }
                ForEach(Array(pathStack.enumerated()), id: \.offset) { idx, url in
                    CmpIcon(name: "chevron", size: 11, color: .text3(theme.dark))
                    breadcrumbButton(
                        label: url.lastPathComponent,
                        isLast: idx == pathStack.count - 1
                    ) {
                        pathStack = Array(pathStack.prefix(idx + 1))
                    }
                }
                Spacer()
                Text("\(items.count) éléments · \(ByteFormatter.string(total))")
                    .font(.system(size: 12)).foregroundColor(.text3(theme.dark))
            }
            .padding(.horizontal, 28)

            HStack(alignment: .top, spacing: 12) {
                GlassPanel(radius: 12, padding: 6) {
                    GeometryReader { geo in
                        ZStack {
                            Treemap(items: items, hovered: $hoveredID, geo: geo.size,
                                    onDrill: { drill(into: $0) },
                                    onReveal: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) })
                            if loadingLevel {
                                ProgressView().controlSize(.large)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.ultraThinMaterial)
                            } else if items.isEmpty {
                                Text("Dossier vide ou illisible")
                                    .font(.system(size: 13)).foregroundColor(.text3(theme.dark))
                            }
                        }
                    }
                    .frame(height: 420)
                }

                GlassPanel(radius: 12, padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LÉGENDE").font(.system(size: 11, weight: .semibold))
                            .tracking(0.6).foregroundColor(.text3(theme.dark))

                        ScrollView {
                            VStack(spacing: 2) {
                                ForEach(Array(items.prefix(20).enumerated()), id: \.element.id) { idx, item in
                                    LegendRow(
                                        item: item,
                                        index: idx,
                                        total: total,
                                        hovered: hoveredID == item.id,
                                        onHover: { isOn in
                                            hoveredID = isOn ? item.id : nil
                                        },
                                        onDrill: { drill(into: item) },
                                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(width: 280)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func breadcrumbButton(label: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isLast ? .text1(theme.dark) : theme.accent.color)
        }
        .buttonStyle(.plain)
    }

    private func drill(into item: ScanItem) {
        // Descend into directories only (files aren't explorable). Stay in-app.
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: item.url.path, isDirectory: &isDir),
              isDir.boolValue else { return }
        let url = item.url
        pathStack.append(url)
        hoveredID = nil
        if levelCache[url.path] != nil { return }   // already loaded
        loadingLevel = true
        Task {
            let kids = await Task.detached(priority: .utility) {
                SpaceLensScanner.scanChildren(of: url)
            }.value
            await MainActor.run {
                levelCache[url.path] = kids
                loadingLevel = false
            }
        }
    }
}

// MARK: – Treemap

private func paletteColor(_ i: Int) -> Color {
    let p: [Color] = [
        .cmpInfo, .cmpViolet, .cmpWarn,
        Color(red: 255/255, green: 159/255, blue: 10/255),
        .cmpBad,
        Color(red: 191/255, green: 90/255, blue: 242/255),
        Color(red: 0/255, green: 217/255, blue: 163/255),
        .cmpGood,
    ]
    return p[i % p.count]
}

private struct Treemap: View {
    let items: [ScanItem]
    @Binding var hovered: UUID?
    let geo: CGSize
    var onDrill: (ScanItem) -> Void
    var onReveal: (ScanItem) -> Void

    var body: some View {
        let total = items.reduce(0) { $0 + $1.size }
        let rects = SquarifyLayout.layout(
            sizes: items.map { Double($0.size) / Double(max(total, 1)) },
            in: CGRect(origin: .zero, size: geo)
        )
        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                if idx < rects.count {
                    let r = rects[idx]
                    let color = paletteColor(idx)
                    let isHovered = hovered == item.id
                    Tile(item: item, rect: r, color: color, hovered: isHovered)
                        .onHover { hovered = $0 ? item.id : nil }
                        .onTapGesture { onDrill(item) }
                        .contextMenu {
                            Button("Explorer") { onDrill(item) }
                            Button("Révéler dans le Finder") { onReveal(item) }
                        }
                }
            }
        }
    }
}

private struct Tile: View {
    let item: ScanItem
    let rect: CGRect
    let color: Color
    let hovered: Bool

    var body: some View {
        let big = rect.width > 80 && rect.height > 36
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(hovered ? 1 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white, lineWidth: hovered ? 1.5 : 0)
                )
                .shadow(color: hovered ? color.opacity(0.6) : .clear, radius: 8)

            if big {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1).truncationMode(.middle)
                    Text(ByteFormatter.string(item.size))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(8)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
            } else if rect.width > 50 && rect.height > 22 {
                Text(ByteFormatter.string(item.size))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: rect.width, height: rect.height)
            }
        }
        .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
        .offset(x: rect.minX + 1, y: rect.minY + 1)
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

private struct LegendRow: View {
    @Environment(\.theme) private var theme
    let item: ScanItem
    let index: Int
    let total: Int64
    let hovered: Bool
    var onHover: (Bool) -> Void
    var onDrill: () -> Void
    var onReveal: () -> Void

    var body: some View {
        let pct = Double(item.size) / Double(max(total, 1)) * 100
        Button(action: onDrill) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(paletteColor(index))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.name).font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.text1(theme.dark))
                        .lineLimit(1).truncationMode(.middle)
                    Text(String(format: "%.1f%% · %@", pct, ByteFormatter.string(item.size)))
                        .font(.system(size: 10.5)).foregroundColor(.text3(theme.dark))
                }
                Spacer()
                CmpIcon(name: "chevron", size: 11, color: .text3(theme.dark))
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .background(hovered ? Color.black.opacity(0.04) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .contextMenu {
            Button("Explorer") { onDrill() }
            Button("Révéler dans le Finder") { onReveal() }
        }
    }
}

// MARK: – Squarified layout

private enum SquarifyLayout {
    /// Returns a rect per input size (fractions of 1). Implements the simple
    /// row/column slice-and-dice variant used by the design prototype.
    static func layout(sizes: [Double], in container: CGRect) -> [CGRect] {
        guard !sizes.isEmpty else { return [] }
        var out = Array(repeating: CGRect.zero, count: sizes.count)
        recurse(sizes: sizes.enumerated().map { ($0.offset, $0.element) },
                in: container, into: &out)
        return out
    }

    private static func recurse(sizes: [(Int, Double)], in rect: CGRect, into out: inout [CGRect]) {
        if sizes.isEmpty { return }
        if sizes.count == 1 {
            out[sizes[0].0] = rect
            return
        }
        let half = sizes.count / 2
        let first = Array(sizes.prefix(half))
        let second = Array(sizes.suffix(sizes.count - half))
        let firstSum = first.reduce(0) { $0 + $1.1 }
        let totalSum = sizes.reduce(0) { $0 + $1.1 }
        let frac = firstSum / max(totalSum, 0.0001)

        let r1: CGRect
        let r2: CGRect
        if rect.width > rect.height {
            let w = rect.width * frac
            r1 = CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height)
            r2 = CGRect(x: rect.minX + w, y: rect.minY, width: rect.width - w, height: rect.height)
        } else {
            let h = rect.height * frac
            r1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h)
            r2 = CGRect(x: rect.minX, y: rect.minY + h, width: rect.width, height: rect.height - h)
        }
        recurse(sizes: first, in: r1, into: &out)
        recurse(sizes: second, in: r2, into: &out)
    }
}
