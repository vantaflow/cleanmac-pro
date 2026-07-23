import SwiftUI

/// The big circular module-colored scan button that sits at the bottom-center of
/// every CleanMyMac 5 module screen.
struct RoundScanButton: View {
    let label: String
    let accent: Color
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(1.0), accent.opacity(0.78)],
                            center: .init(x: 0.4, y: 0.32), startRadius: 2, endRadius: 90)
                    )
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.08)],
                                           startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                    )
                    .shadow(color: accent.opacity(0.6), radius: hover ? 26 : 18, y: 6)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 132, height: 132)
            .scaleEffect(hover ? 1.03 : 1)
            .animation(.easeOut(duration: 0.15), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
