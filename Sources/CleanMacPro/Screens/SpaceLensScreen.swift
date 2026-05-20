import SwiftUI
import CleanCore

/// Treemap visualisation of disk usage. Falls back to the generic listing
/// underneath the map for selection / drill-down.
struct SpaceLensScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        let state = appState.state(for: .spaceLens)
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(
                title: "Space Lens",
                subtitle: "Carte interactive du dossier utilisateur. Survol pour voir la taille."
            ) {
                if state.isScanning {
                    Btn(kind: .secondary, icon: "pause", label: "Annuler") {
                        appState.cancelScan(module: .spaceLens)
                    }
                } else {
                    Btn(kind: .primary, size: .lg, icon: "scan", label: "Scanner mon disque") {
                        appState.startScan(module: .spaceLens)
                    }
                }
            }

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
                Treemap(items: result.items.prefix(40).map { $0 })
                    .frame(height: 380)
                    .padding(.horizontal, 28)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(result.items.prefix(20)) { item in
                            HStack {
                                Circle().fill(colorForIndex(result.items.firstIndex(of: item) ?? 0))
                                    .frame(width: 8, height: 8)
                                Text(item.name).font(.system(size: 13)).foregroundColor(.text1(theme.dark))
                                Spacer()
                                Text(ByteFormatter.string(item.size))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.text2(theme.dark))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 28).padding(.bottom, 60)
                }
            } else {
                VStack(spacing: 14) {
                    Spacer()
                    CmpIcon(name: "disk", size: 56, color: .text3(theme.dark))
                    Text("Lance un scan pour cartographier ton disque")
                        .font(.system(size: 14)).foregroundColor(.text2(theme.dark))
                    Btn(kind: .primary, size: .lg, icon: "play", label: "Scanner") {
                        appState.startScan(module: .spaceLens)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 28)
    }
}

private func colorForIndex(_ i: Int) -> Color {
    let palette: [Color] = [
        .cmpInfo, .cmpViolet, .cmpWarn, .cmpGood, .cmpBad,
        Color(red: 191/255, green: 90/255, blue: 242/255),
        Color(red: 255/255, green: 159/255, blue: 10/255),
        Color(red: 0/255, green: 217/255, blue: 163/255),
    ]
    return palette[i % palette.count]
}

private struct Treemap: View {
    let items: [ScanItem]

    var body: some View {
        GeometryReader { geo in
            let total = items.reduce(Int64(0)) { $0 + $1.size }
            let rects = TreemapLayout.layout(
                sizes: items.map { Double($0.size) / Double(max(total, 1)) },
                in: CGRect(origin: .zero, size: geo.size)
            )
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if idx < rects.count {
                        TreemapTile(item: item, color: colorForIndex(idx), rect: rects[idx])
                    }
                }
            }
        }
    }
}

private struct TreemapTile: View {
    let item: ScanItem
    let color: Color
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.75))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: rect.width > 100 ? 12 : 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                if rect.height > 40 {
                    Text(ByteFormatter.string(item.size))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(6)
        }
        .frame(width: max(rect.width - 2, 0), height: max(rect.height - 2, 0))
        .offset(x: rect.minX + 1, y: rect.minY + 1)
    }
}

/// Squarified-ish treemap (simplified: row-then-column slice-and-dice).
private enum TreemapLayout {
    static func layout(sizes: [Double], in rect: CGRect) -> [CGRect] {
        guard !sizes.isEmpty else { return [] }
        return sliceAndDice(sizes: sizes, in: rect, horizontal: rect.width > rect.height)
    }

    private static func sliceAndDice(sizes: [Double], in rect: CGRect, horizontal: Bool) -> [CGRect] {
        if sizes.count == 1 { return [rect] }
        let half = sizes.prefix(max(1, sizes.count / 2))
        let other = sizes.suffix(from: half.count)
        let halfSum = half.reduce(0, +)
        let totalSum = sizes.reduce(0, +)
        let frac = halfSum / max(totalSum, 0.0001)

        let r1: CGRect
        let r2: CGRect
        if horizontal {
            let w = rect.width * frac
            r1 = CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height)
            r2 = CGRect(x: rect.minX + w, y: rect.minY, width: rect.width - w, height: rect.height)
        } else {
            let h = rect.height * frac
            r1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: h)
            r2 = CGRect(x: rect.minX, y: rect.minY + h, width: rect.width, height: rect.height - h)
        }
        return sliceAndDice(sizes: Array(half), in: r1, horizontal: !horizontal)
             + sliceAndDice(sizes: Array(other), in: r2, horizontal: !horizontal)
    }
}
