import SwiftUI

struct SunburstSlice: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let label: String
    let value: Double
    let color: Color
}

struct StorageSunburst: View {
    @Environment(\.theme) private var theme
    var size: CGFloat = 220
    var slices: [SunburstSlice]
    var used: Double
    var total: Double
    var defaultKey: String? = nil

    @State private var hovered: SunburstSlice? = nil

    private var total2: Double { max(slices.reduce(0) { $0 + $1.value }, 0.0001) }

    private var center: (label: String, value: String, sub: String) {
        let s = hovered ?? slices.first { $0.key == defaultKey } ?? slices.first
        if let s {
            let pct = s.value / max(total, 1) * 100
            return (s.label.uppercased(), String(format: "%.1f Go", s.value), String(format: "%.1f%% du disque", pct))
        }
        return ("STOCKAGE", String(format: "%.0f Go", used), "de \(Int(total)) Go")
    }

    var body: some View {
        ZStack {
            ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                SliceShape(slice: slice, slices: slices, hovered: hovered?.id == slice.id)
                    .fill(slice.color.gradient.opacity(0.95))
                    .shadow(color: hovered?.id == slice.id ? slice.color.opacity(0.6) : .clear, radius: 8)
                    .onHover { hover in hovered = hover ? slice : nil }
                    .animation(.easeOut(duration: 0.18), value: hovered?.id)
            }

            VStack(spacing: 4) {
                Text(center.label).font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.8).foregroundColor(.text3(theme.dark))
                Text(center.value).font(.system(size: 30, weight: .bold))
                    .tracking(-1.05).foregroundColor(.text1(theme.dark))
                Text(center.sub).font(.system(size: 11.5))
                    .foregroundColor(.text2(theme.dark))
            }
            .allowsHitTesting(false)
            .padding(.horizontal, size * 0.06)
        }
        .frame(width: size, height: size)
    }
}

private struct SliceShape: Shape {
    let slice: SunburstSlice
    let slices: [SunburstSlice]
    let hovered: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rOuterBase = min(rect.width, rect.height) / 2 - 6
        let rOuter = rOuterBase + (hovered ? 4 : 0)
        let rInner = rOuterBase * 0.62

        var acc = 0.0
        for s in slices {
            let a0 = (acc / total) * 2 * .pi - .pi / 2
            acc += s.value
            let a1 = (acc / total) * 2 * .pi - .pi / 2
            if s.id == slice.id {
                let pad = 0.012  // tiny radial gap between slices
                let aStart = Angle(radians: a0 + pad)
                let aEnd = Angle(radians: a1 - pad)
                path.move(to: CGPoint(
                    x: center.x + cos(aStart.radians) * rOuter,
                    y: center.y + sin(aStart.radians) * rOuter
                ))
                path.addArc(center: center, radius: rOuter,
                            startAngle: aStart, endAngle: aEnd, clockwise: false)
                path.addLine(to: CGPoint(
                    x: center.x + cos(aEnd.radians) * rInner,
                    y: center.y + sin(aEnd.radians) * rInner
                ))
                path.addArc(center: center, radius: rInner,
                            startAngle: aEnd, endAngle: aStart, clockwise: true)
                path.closeSubpath()
                break
            }
        }
        return path
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
