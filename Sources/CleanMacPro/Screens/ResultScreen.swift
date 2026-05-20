import SwiftUI
import CleanCore

struct ResultScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    @State private var animateIn = false

    private var freedBytes: Int64 {
        appState.moduleStates.values.compactMap { $0.lastReport?.freedBytes }.reduce(0, +)
    }
    private var freedCount: Int {
        appState.moduleStates.values.compactMap { $0.lastReport?.removedCount }.reduce(0, +)
    }
    private var freedGB: Double { Double(freedBytes) / 1_000_000_000 }

    private var breakdown: [(ModuleID, CleanReport)] {
        appState.moduleStates
            .compactMap { (key, value) in value.lastReport.map { (key, $0) } }
            .filter { $0.1.removedCount > 0 }
            .sorted { $0.1.freedBytes > $1.1.freedBytes }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer().frame(height: 24)

                    // "Nettoyage terminé" pill
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 15/255, green: 138/255, blue: 55/255))
                        Text(freedBytes == 0 ? "Aucun nettoyage récent" : "Nettoyage terminé")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 15/255, green: 138/255, blue: 55/255))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.cmpGood.opacity(0.14))
                    .clipShape(Capsule())
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)

                    VStack(spacing: 8) {
                        Text("BOOM.").font(.system(size: 14, weight: .semibold))
                            .tracking(0.6).foregroundColor(.text3(theme.dark))

                        // Mega gradient number
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(String(format: "%.1f", freedGB))
                                .font(.system(size: 96, weight: .heavy))
                                .tracking(-4.5)
                            Text("Go")
                                .font(.system(size: 56, weight: .heavy))
                                .tracking(-2)
                                .foregroundColor(.text2(theme.dark))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    theme.accent.color,
                                    Color(red: 0, green: 0.63, blue: 0.48),
                                    Color.text1(theme.dark)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .lineLimit(1).minimumScaleFactor(0.6)

                        Text(freedBytes == 0
                             ? "Lance un scan pour récupérer de l'espace."
                             : "récupérés. Ton Mac respire.")
                            .font(.system(size: 18))
                            .foregroundColor(.text2(theme.dark))

                        if freedBytes > 0 {
                            Text(approxLine(freedGB)).font(.system(size: 13.5))
                                .foregroundColor(.text3(theme.dark))
                        }
                    }
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 24)

                    if !breakdown.isEmpty {
                        breakdownPanel
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 24)
                    }

                    HStack(spacing: 12) {
                        suggestionCard(
                            icon: "sparkle", color: theme.accent.color,
                            title: "Pendant qu'on y est",
                            body: "Tu peux relancer un Smart Scan : caches récents, traceurs accumulés, mises à jour."
                        ) {
                            appState.active = .smartScan
                        }
                        suggestionCard(
                            icon: "wrench", color: .cmpViolet,
                            title: "Maintenance",
                            body: "Vider le cache DNS, réindexer Spotlight, purger la RAM en quelques secondes."
                        ) {
                            appState.active = .maintenance
                        }
                    }
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 24)

                    Btn(kind: .ghost, label: "Retour à la vue d'ensemble") {
                        appState.active = .dashboard
                    }
                    .padding(.top, 8)
                    .opacity(animateIn ? 1 : 0)
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 28).padding(.bottom, 80)
                .frame(maxWidth: .infinity)
            }

            if freedBytes > 0 && animateIn {
                ConfettiView().allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { animateIn = true }
        }
    }

    private var breakdownPanel: some View {
        GlassPanel(radius: 14, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("DÉTAIL").font(.system(size: 11, weight: .semibold))
                    .tracking(0.7).foregroundColor(.text3(theme.dark))
                ForEach(Array(breakdown.enumerated()), id: \.offset) { idx, pair in
                    HStack(spacing: 14) {
                        let gb = Double(pair.1.freedBytes) / 1_000_000_000
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(theme.accent.color.opacity(0.18))
                            Text(String(format: "%.1f", gb))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(theme.accent.color)
                        }
                        .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.0.title).font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.text1(theme.dark))
                            Text("\(pair.1.removedCount) éléments envoyés à la Corbeille")
                                .font(.system(size: 11.5))
                                .foregroundColor(.text3(theme.dark))
                        }
                        Spacer()
                        Text(ByteFormatter.string(pair.1.freedBytes))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.text1(theme.dark))
                    }
                    if idx < breakdown.count - 1 {
                        Divider().background(Color.hairlineSoft(theme.dark))
                    }
                }
            }
        }
    }

    private func suggestionCard(icon: String, color: Color, title: String, body: String, action: @escaping () -> Void) -> some View {
        GlassPanel(radius: 12, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CmpIcon(name: icon, size: 16, color: color)
                    Text(title).font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.text1(theme.dark))
                }
                Text(body).font(.system(size: 12.5))
                    .foregroundColor(.text2(theme.dark))
                    .fixedSize(horizontal: false, vertical: true)
                Btn(kind: .secondary, size: .sm, label: "Y aller", action: action)
            }
        }
    }

    private func approxLine(_ gb: Double) -> String {
        let photos = Int(gb * 1000 / 4)        // ~4 MB / photo
        let films = Int(gb / 8)                // ~8 GB / 4K film
        return "Soit ~ \(photos.formatted()) photos · \(films) film\(films > 1 ? "s" : "") 4K"
    }
}

// MARK: – Confetti

private struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let duration: Double
        let color: Color
        let size: CGFloat
        let rotate: Double
    }

    @State private var pieces: [Piece] = []
    @State private var trigger = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    Rectangle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 0.4)
                        .rotationEffect(.degrees(trigger ? p.rotate + 540 : p.rotate))
                        .position(
                            x: p.x * geo.size.width,
                            y: trigger ? geo.size.height + 60 : -40
                        )
                        .animation(
                            .easeIn(duration: p.duration).delay(p.delay),
                            value: trigger
                        )
                        .opacity(trigger ? 0 : 1)
                }
            }
        }
        .onAppear {
            let palette: [Color] = [
                .cmpInfo, .cmpViolet, .cmpWarn, .cmpGood, .cmpBad,
                Color(red: 0, green: 0.85, blue: 0.64)
            ]
            pieces = (0..<60).map { i in
                Piece(
                    x: .random(in: 0...1),
                    delay: .random(in: 0...0.5),
                    duration: .random(in: 1.8...3.2),
                    color: palette[i % palette.count],
                    size: CGFloat.random(in: 6...11),
                    rotate: .random(in: 0...360)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                trigger = true
            }
        }
    }
}
