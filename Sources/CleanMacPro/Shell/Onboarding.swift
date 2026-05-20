import SwiftUI
import CleanCore

struct OnboardingOverlay: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            Color(white: 0.08).opacity(0.92).ignoresSafeArea()

            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.accent.color.opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: 380
                    )
                )
                .frame(width: 760, height: 760)
                .blur(radius: 24)
                .allowsHitTesting(false)

            VStack(spacing: 24) {
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: transparencyStep
                    default: readyStep
                    }
                }
                .id(step)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                // Stepper dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Capsule()
                            .fill(i <= step ? theme.accent.color : Color.white.opacity(0.2))
                            .frame(width: i == step ? 24 : 6, height: 6)
                            .animation(.easeOut(duration: 0.2), value: step)
                    }
                }

                HStack(spacing: 10) {
                    if step > 0 {
                        Btn(kind: .ghost, label: "Retour") { step -= 1 }
                    }
                    Btn(kind: .primary, size: .lg,
                        icon: step == 2 ? "scan" : nil,
                        label: step == 0 ? "Continuer" : step == 1 ? "C'est noté"
                                                                   : "Lancer le premier scan") {
                        if step < 2 { step += 1 }
                        else {
                            appState.dismissOnboarding()
                            appState.active = .smartScan
                            let modules: [ModuleID] = [.cleanup, .files, .security, .updates, .privacy]
                            modules.forEach { appState.startScan(module: $0) }
                        }
                    }
                }

                if step < 2 {
                    Button("Passer l'intro") {
                        appState.dismissOnboarding()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: 520)
            .padding(40)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: – Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.047, green: 0.122, blue: 0.102),
                            Color(red: 0.039, green: 0.20, blue: 0.16)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .shadow(color: theme.accent.color.opacity(0.45), radius: 30, y: 12)
                CmpLogo(size: 88, accent: theme.accent.color)
            }

            Text("Salut. Je suis ").font(.system(size: 34, weight: .bold)).tracking(-1)
            + Text("CleanMac Pro").font(.system(size: 34, weight: .bold))
                .tracking(-1).foregroundColor(theme.accent.color)
            + Text(".").font(.system(size: 34, weight: .bold)).tracking(-1)

            Text("Je libère de l'espace, je tue les apps fantômes et je supprime les traces. Sans pop-ups marketing. Sans paniquer.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
    }

    private struct TransparencyItem: Identifiable {
        let id = UUID()
        let ok: Bool
        let label: String
    }
    private let transparency: [TransparencyItem] = [
        .init(ok: true,  label: "Caches, logs, anciens .dmg, corbeilles"),
        .init(ok: true,  label: "Apps non ouvertes depuis 6+ mois"),
        .init(ok: true,  label: "Cookies tiers et traceurs"),
        .init(ok: false, label: "Tes documents, photos, iCloud"),
        .init(ok: false, label: "Mots de passe, clés, données chiffrées"),
        .init(ok: false, label: "Aucune télémétrie. Tout reste local."),
    ]

    private var transparencyStep: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                CmpIcon(name: "shield", size: 36, color: theme.accent.color)
            }

            VStack(spacing: 6) {
                Text("Ce que je touche.").font(.system(size: 28, weight: .bold)).tracking(-0.7)
                Text("Ce que je ne touche jamais.")
                    .font(.system(size: 28, weight: .bold)).tracking(-0.7)
                    .underline(true, color: theme.accent.color)
            }
            .foregroundColor(.white)

            Text("Aucune ambiguïté. Promis.")
                .font(.system(size: 13.5)).foregroundColor(.white.opacity(0.55))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(transparency) { it in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill((it.ok ? Color.cmpGood : Color.cmpBad).opacity(0.2))
                            Image(systemName: it.ok ? "checkmark" : "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(it.ok ? .cmpGood : .cmpBad)
                        }
                        .frame(width: 18, height: 18)
                        Text(it.label).font(.system(size: 12))
                            .foregroundColor(.white)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background((it.ok ? Color.cmpGood : Color.cmpBad).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke((it.ok ? Color.cmpGood : Color.cmpBad).opacity(0.25), lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    private var readyStep: some View {
        VStack(spacing: 22) {
            ScanVisualMini(accent: theme.accent.color)
            Text("Premier scan. ")
                .font(.system(size: 30, weight: .bold)).tracking(-0.6)
            + Text("~30 secondes.")
                .font(.system(size: 30, weight: .bold)).tracking(-0.6)
                .foregroundColor(theme.accent.color)
            Text("Je regarde partout où macOS et tes apps stockent des trucs temporaires. Tu choisis ce qui part — rien n'est supprimé sans toi.")
                .font(.system(size: 14.5))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
    }
}

private struct ScanVisualMini: View {
    let accent: Color
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle().stroke(accent, lineWidth: 1.5).frame(width: 140, height: 140).opacity(0.2)
            Circle().stroke(accent, lineWidth: 1.5).frame(width: 100, height: 100).opacity(0.35)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 60, height: 60).opacity(0.6)
                .rotationEffect(.degrees(rotate ? 360 : 0))
            Circle()
                .fill(accent)
                .frame(width: 50, height: 50)
                .shadow(color: accent.opacity(0.6), radius: 24)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}
