import SwiftUI

struct MiniStat: View {
    @Environment(\.theme) private var theme
    var icon: String
    var color: Color
    var label: String
    var value: String
    var sub: String
    var action: () -> Void = {}

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18))
                    CmpIcon(name: icon, size: 15, color: color)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 11)).foregroundColor(.text3(theme.dark))
                    Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.text1(theme.dark))
                    Text(sub).font(.system(size: 11)).foregroundColor(.text3(theme.dark))
                }
                Spacer()
                CmpIcon(name: "chevron", size: 13, color: hover ? .text1(theme.dark) : .text3(theme.dark))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(hover ? Color.black.opacity(0.04) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
