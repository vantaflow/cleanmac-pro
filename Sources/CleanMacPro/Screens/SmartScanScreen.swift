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
                        .frame(width: 240, height: 240)
                        .animation(.easeOut(duration: 0.4), value: aggregatedProgress)
                }
                ModuleGlyph(symbol: "scan", size: 190, tint: ModuleID.smartScan.glyphTint)
            }
            .padding(.bottom, 20)

            Text(headline)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(subline)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .frame(maxWidth: 460)

            // Category chips.
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { m in
                    categoryChip(m)
                }
            }
            .padding(.top, 26)

            Spacer()

            // Primary action.
            Button(action: primaryAction) {
                HStack(spacing: 9) {
                    CmpIcon(name: anyScanning ? "pause" : "scan", size: 15, color: Color(red: 0.14, green: 0.16, blue: 0.36))
                    Text(actionLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.14, green: 0.16, blue: 0.36))
                }
                .padding(.horizontal, 30).padding(.vertical, 14)
                .background(Capsule().fill(Color.white))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    private var headline: String {
        if anyScanning { return "Analyse en cours…" }
        if scanned { return reclaimable > 0 ? "\(ByteFormatter.string(reclaimable)) à récupérer" : "Ton Mac est impeccable." }
        return "Ton Mac va bien."
    }
    private var subline: String {
        if anyScanning { return "Nettoyage, fichiers, protection, mises à jour et confidentialité." }
        if scanned { return reclaimable > 0 ? "Passe en revue et lance le nettoyage en un clic." : "Rien à nettoyer pour le moment. Reviens plus tard." }
        return "Lance Smart Care pour voir ce qu'il y a à récupérer et à protéger."
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
