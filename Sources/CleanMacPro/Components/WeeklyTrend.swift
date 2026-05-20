import SwiftUI

struct DayValue: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

struct WeeklyTrend: View {
    @Environment(\.theme) private var theme
    var data: [DayValue]
    var title: String = "Récupéré cette semaine"
    var sub: String = "+38% vs semaine passée"

    private var maxValue: Double { max(data.map(\.value).max() ?? 1, 1) }
    private var total: Double { data.reduce(0) { $0 + $1.value } }

    var body: some View {
        GlassPanel(radius: 12, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.uppercased()).font(.system(size: 10, weight: .semibold))
                            .tracking(1).foregroundColor(.text3(theme.dark))
                        Text(String(format: "%.1f Go", total))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.text1(theme.dark))
                    }
                    Spacer()
                    StatusPill(status: .good, text: sub)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(data) { d in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.accent.color)
                                .frame(width: 22, height: max(4, CGFloat(d.value / maxValue) * 70))
                            Text(d.day).font(.system(size: 10, weight: .medium))
                                .foregroundColor(.text3(theme.dark))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 88)
            }
        }
    }
}
