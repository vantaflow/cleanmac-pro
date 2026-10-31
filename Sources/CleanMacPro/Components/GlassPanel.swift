import SwiftUI

/// Standard card surface (kept under its historical name).
struct GlassPanel<Content: View>: View {
    @Environment(\.theme) private var theme
    var radius: CGFloat = Radius.l
    var padding: CGFloat = 0
    var border: Color? = nil
    var dashed: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .cardSurface(dark: theme.dark, radius: radius, border: border, dashed: dashed)
    }
}
