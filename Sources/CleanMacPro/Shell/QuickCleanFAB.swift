import SwiftUI

struct QuickCleanFAB: View {
    @Environment(\.theme) private var theme
    var action: () -> Void

    @State private var pulse = false
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(theme.accent.onAccent.opacity(0.4), lineWidth: 1.5)
                        .frame(width: pulse ? 32 : 22, height: pulse ? 32 : 22)
                        .opacity(pulse ? 0 : 0.7)
                    CmpIcon(name: "bolt", size: 18, color: theme.accent.onAccent)
                }
                .frame(width: 24, height: 24)

                Text("Quick Clean").font(.system(size: 14, weight: .bold))
                    .tracking(-0.05)

                Text("⌘⇧K")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, hover ? 22 : 18)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [theme.accent.color,
                             theme.accent.color.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .foregroundColor(theme.accent.onAccent)
            .shadow(color: theme.accent.color.opacity(0.45), radius: 18, y: 8)
            .offset(y: hover ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
    }
}
