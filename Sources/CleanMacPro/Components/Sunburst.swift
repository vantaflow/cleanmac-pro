import SwiftUI

struct SunburstSlice: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct StorageSunburst: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 220
    var slices: [SunburstSlice]
    var centerTitle: String
    var centerSubtitle: String

    @State private var hovered: SunburstSlice? = nil

    private var total: Double { max(slices.reduce(0) { $0 + $1.value }, 0.001) }

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width/2, y: sz.height/2)
                let outerR = min(sz.width, sz.height)/2
                let innerR = outerR * 0.55
                var startAngle = Angle.degrees(-90)
                for slice in slices {
                    let frac = slice.value / total
                    let endAngle = startAngle + .degrees(frac * 360)
                    var path = Path()
                    path.move(to: CGPoint(
                        x: center.x + cos(startAngle.radians) * innerR,
                        y: center.y + sin(startAngle.radians) * innerR
                    ))
                    path.addArc(center: center, radius: outerR,
                                startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    path.addArc(center: center, radius: innerR,
                                startAngle: endAngle, endAngle: startAngle, clockwise: true)
                    path.closeSubpath()
                    ctx.fill(path, with: .color(slice.color))
                    startAngle = endAngle
                }
            }
            .frame(width: size, height: size)

            VStack(spacing: 2) {
                Text(centerTitle)
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundColor(.text1(theme.dark))
                Text(centerSubtitle)
                    .font(.system(size: size * 0.06))
                    .foregroundColor(.text3(theme.dark))
            }
        }
        .frame(width: size, height: size)
    }
}

struct SunburstLegend: View {
    @Environment(\.theme) private var theme
    var slices: [SunburstSlice]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle().fill(slice.color).frame(width: 8, height: 8)
                    Text(slice.label).font(.system(size: 11.5)).foregroundColor(.text2(theme.dark))
                    Spacer()
                    Text(String(format: "%.1f Go", slice.value))
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.text1(theme.dark))
                }
            }
        }
    }
}
