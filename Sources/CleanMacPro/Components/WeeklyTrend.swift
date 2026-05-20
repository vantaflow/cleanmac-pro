import SwiftUI

struct DayValue: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

struct WeeklyTrend: View {
    @Environment(\.theme) private var theme
    var data: [DayValue]
    var subtitle: String = "+ 38% vs la sem. passée"

    private var maxValue: Double { max(data.map(\.value).max() ?? 1, 1) }
    private var total: Double { data.reduce(0) { $0 + $1.value } }

    var body: some View {
        GlassPanel(radius: 14, padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CETTE SEMAINE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.7)
                            .foregroundColor(.text3(theme.dark))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%.1f Go", total))
                                .font(.system(size: 20, weight: .bold))
                                .tracking(-0.4)
                                .foregroundColor(theme.accent.color)
                            Text("récupérés en 7 jours")
                                .font(.system(size: 13))
                                .foregroundColor(.text2(theme.dark))
                        }
                    }
                    Spacer()
                    StatusPill(status: .good, text: subtitle)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { idx, d in
                        let isToday = idx == data.count - 1
                        VStack(spacing: 4) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: isToday
                                                    ? [theme.accent.color, theme.accent.color.opacity(0.7)]
                                                    : [theme.accent.color.opacity(0.5),
                                                       theme.accent.color.opacity(0.15)],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .overlay(
                                            isToday
                                                ? RoundedRectangle(cornerRadius: 4)
                                                    .stroke(theme.accent.color.opacity(0.6), lineWidth: 0.5)
                                                : nil
                                        )
                                        .frame(height: max(4, geo.size.height * CGFloat(d.value / maxValue)))
                                }
                            }
                            .frame(height: 62)
                            Text(d.day)
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundColor(isToday ? .text1(theme.dark) : .text3(theme.dark))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 86)
            }
        }
    }
}
