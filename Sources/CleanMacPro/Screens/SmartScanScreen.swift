import SwiftUI
import CleanCore

/// Smart Care — the CleanMyMac 5 home. One glossy hero glyph, a headline, and a
/// single Scan action that fans out to Cleanup / Files / Protection / Updates /
/// Privacy in parallel with live per-category progress.
struct SmartScanScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private let categories: [ModuleID] = [.cleanup, .files, .security, .updates, .privacy]

    private var aggregatedProgress: Double {
        let v = categories.map { appState.state(for: $0).progress }
        return v.reduce(0, +) / Double(max(v.count, 1))
    }
    private var anyScanning: Bool { categories.contains { appState.state(for: $0).isScanning } }
    private var scanned: Bool { categories.allSatisfy { appState.state(for: $0).result != nil } }
    private var reclaimable: Int64 {
        categories.reduce(0) { $0 + (appState.state(for: $1).result?.totalSize ?? 0) }
    }

    private var accent: Color { ModuleID.smartScan.theme.accent }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            // Hero glyph with progress ring while scanning.
            ZStack {
                if anyScanning {
                    Circle()
                        .trim(from: 0, to: aggregatedProgress)
                        .stroke(Color.white.opacity(0.9),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 250, height: 250)
                        .animation(.easeOut(duration: 0.4), value: aggregatedProgress)
                }
                ModuleGlyph(symbol: "desktopcomputer", size: 200, tint: ModuleID.smartScan.glyphTint)
            }
            .padding(.bottom, 14)

            Text(headline)
                .font(.system(size: 44, weight: .regular))
                .tracking(-0.5)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(subline)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)
                .frame(maxWidth: 500)

            // Category chips (only once a scan has run / is running).
            if anyScanning || scanned {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { m in
                        categoryChip(m)
                    }
                }
                .padding(.top, 26)
            }

            Spacer()

            RoundScanButton(label: actionLabel, accent: accent, action: primaryAction)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private var headline: String {
        if anyScanning { return "Analyse en cours…" }
        if scanned { return reclaimable > 0 ? "\(ByteFormatter.string(reclaimable)) à récupérer" : "Votre Mac est impeccable." }
        return "Heureux de vous revoir !"
    }
    private var subline: String {
        if anyScanning { return "Nettoyage, fichiers, protection, mises à jour et confidentialité." }
        if scanned { return reclaimable > 0 ? "Passez en revue puis lancez le nettoyage en un clic." : "Rien à nettoyer pour le moment. Revenez plus tard." }
        return "Pour commencer, lancez une analyse rapide et complète de votre Mac."
    }
    private var actionLabel: String {
        if anyScanning { return "Arrêter" }
        if scanned && reclaimable > 0 { return "Nettoyer" }
        return "Analyser"
    }

    private func primaryAction() {
        if anyScanning {
            categories.forEach { appState.cancelScan(module: $0) }
        } else if scanned && reclaimable > 0 {
            appState.quickClean()
        } else {
            categories.forEach { appState.startScan(module: $0) }
        }
    }

    private func categoryChip(_ m: ModuleID) -> some View {
        let s = appState.state(for: m)
        let done = s.result != nil && !s.isScanning
        return VStack(spacing: 7) {
            ZStack {
                ModuleGlyph(symbol: m.symbol, size: 40, tint: m.glyphTint)
                if s.isScanning {
                    Circle().trim(from: 0, to: s.progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 46, height: 46)
                } else if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .background(Circle().fill(m.glyphTint[1]).frame(width: 15, height: 15))
                        .offset(x: 16, y: -16)
                }
            }
            Text(m.railTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: 78)
    }
}
