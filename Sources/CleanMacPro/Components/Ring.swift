import SwiftUI

struct Ring<Content: View>: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 140
    var stroke: CGFloat = 10
    var value: Double
    var maxValue: Double = 100
    var color: Color? = nil
    @ViewBuilder var center: () -> Content

    var body: some View {
        let progress = max(0, min(1, value / maxValue))
        ZStack {
            Circle()
                .stroke(Color.hairline(theme.dark), lineWidth: stroke)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color ?? theme.accent.color,
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            center()
        }
        .frame(width: size, height: size)
    }
}
