import SwiftUI

/// App mark: graphite squircle, two concentric rings and an accent dot.
struct CmpLogo: View {
    var size: CGFloat = 22
    var accent: Color = Accent.mint.color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Accent.mint.tint)
            Circle()
                .stroke(accent.opacity(0.55), lineWidth: size * 0.06)
                .frame(width: size * 0.7, height: size * 0.7)
            Circle()
                .stroke(accent, lineWidth: size * 0.06)
                .frame(width: size * 0.42, height: size * 0.42)
            Circle().fill(Color.white).frame(width: size * 0.15, height: size * 0.15)
        }
        .frame(width: size, height: size)
    }
}
