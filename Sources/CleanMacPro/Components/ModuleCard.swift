import SwiftUI

struct ModuleCard: View {
    @Environment(\.theme) private var theme
    var icon: String
    var color: Color
    var title: String
    var stat: String
    var sub: String
    var action: () -> Void = {}

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            GlassPanel(radius: 12, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18))
                            CmpIcon(name: icon, size: 17, color: color)
                        }
                        .frame(width: 36, height: 36)
                        Spacer()
                        CmpIcon(name: "chevron", size: 14, color: .text3(theme.dark))
                    }
                    Text(title).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.text2(theme.dark))
                    Text(stat).font(.system(size: 22, weight: .bold))
                        .foregroundColor(.text1(theme.dark))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(sub).font(.system(size: 11)).foregroundColor(.text3(theme.dark))
                        .lineLimit(2)
                }
            }
            .scaleEffect(hover ? 1.01 : 1.0)
            .shadow(color: .black.opacity(hover ? 0.08 : 0.0), radius: 8, y: 3)
            .animation(.easeOut(duration: 0.15), value: hover)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
