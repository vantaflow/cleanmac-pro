import SwiftUI

/// Concentric rings + small accent dot, matching the design's `icon.svg`.
struct CmpLogo: View {
    var size: CGFloat = 22
    var accent: Color = Color(red: 0/255, green: 217/255, blue: 163/255)

    var body: some View {
        ZStack {
            // Outer dark squircle
            RoundedRectangle(cornerRadius: size * 0.225)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 21/255, green: 35/255, blue: 65/255),
                        Color(red: 5/255,  green: 8/255,  blue: 18/255)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: size * 0.06)
                .frame(width: size * 0.7, height: size * 0.7)
            // Inner ring
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: size * 0.06)
                .frame(width: size * 0.42, height: size * 0.42)
            // Center dot
            Circle().fill(Color.white).frame(width: size * 0.15, height: size * 0.15)
            // Pulse dot
            Circle().fill(accent)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(y: -size * 0.36)
        }
        .frame(width: size, height: size)
    }
}
