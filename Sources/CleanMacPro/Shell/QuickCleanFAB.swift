import SwiftUI

struct QuickCleanFAB: View {
    @Environment(\.theme) private var theme
    var action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CmpIcon(name: "sparkle", size: 18, color: theme.accent.onAccent)
                Text("Quick Clean").font(.system(size: 13.5, weight: .semibold))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(
                ZStack {
                    Capsule().fill(theme.accent.color)
                    Capsule().stroke(theme.accent.color.opacity(0.6), lineWidth: pulse ? 8 : 0)
                        .opacity(pulse ? 0 : 1)
                }
            )
            .foregroundColor(theme.accent.onAccent)
            .shadow(color: theme.accent.color.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
