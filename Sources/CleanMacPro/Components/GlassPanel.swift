import SwiftUI

struct GlassPanel<Content: View>: View {
    @Environment(\.theme) private var theme
    var radius: CGFloat = 14
    var padding: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color.panel(theme.dark))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.hairline(theme.dark), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}
