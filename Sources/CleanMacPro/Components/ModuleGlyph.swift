import SwiftUI

/// A rounded hexagon, like the CleanMyMac 5 module hero glyphs.
struct RoundedHexagon: Shape {
    var cornerFraction: CGFloat = 0.16
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cx = rect.midX, cy = rect.midY
        let r = min(w, h) / 2
        // Flat-top hexagon vertices.
        var pts: [CGPoint] = []
        for i in 0..<6 {
            let a = (Double(i) * 60.0 - 30.0) * .pi / 180.0
            pts.append(CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a))))
        }
        var p = Path()
        let round = r * cornerFraction
        for i in 0..<6 {
            let curr = pts[i]
            let prev = pts[(i + 5) % 6]
            let next = pts[(i + 1) % 6]
            let toPrev = normalize(CGPoint(x: prev.x - curr.x, y: prev.y - curr.y))
            let toNext = normalize(CGPoint(x: next.x - curr.x, y: next.y - curr.y))
            let start = CGPoint(x: curr.x + toPrev.x * round, y: curr.y + toPrev.y * round)
            let end = CGPoint(x: curr.x + toNext.x * round, y: curr.y + toNext.y * round)
            if i == 0 { p.move(to: start) } else { p.addLine(to: start) }
            p.addQuadCurve(to: end, control: curr)
        }
        p.closeSubpath()
        return p
    }
    private func normalize(_ v: CGPoint) -> CGPoint {
        let len = max(sqrt(v.x * v.x + v.y * v.y), 0.0001)
        return CGPoint(x: v.x / len, y: v.y / len)
    }
}

/// Glossy 3D hero glyph for a module — hexagon with depth, gloss and an SF symbol.
struct ModuleGlyph: View {
    let symbol: String
    var size: CGFloat = 180
    var tint: [Color] = [Color(red: 0.42, green: 0.62, blue: 1.0),
                         Color(red: 0.18, green: 0.30, blue: 0.85)]

    var body: some View {
        ZStack {
            // Ambient glow.
            RoundedHexagon()
                .fill(tint[0].opacity(0.35))
                .blur(radius: size * 0.16)
                .frame(width: size * 1.05, height: size * 1.05)

            // Body.
            RoundedHexagon()
                .fill(
                    LinearGradient(colors: tint, startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedHexagon()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.55), .clear],
                                center: .init(x: 0.32, y: 0.20),
                                startRadius: 0, endRadius: size * 0.7)
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedHexagon()
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.05)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: size * 0.012)
                )
                .frame(width: size, height: size)
                .shadow(color: tint[1].opacity(0.5), radius: size * 0.12, x: 0, y: size * 0.06)

            CmpIcon(name: symbol, size: size * 0.36, color: .white)
                .shadow(color: tint[1].opacity(0.6), radius: 6, y: 3)
        }
        .frame(width: size * 1.1, height: size * 1.1)
    }
}
