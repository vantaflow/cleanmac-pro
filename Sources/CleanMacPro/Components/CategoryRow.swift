import SwiftUI

struct CategoryRow: View {
    @Environment(\.theme) private var theme
    var icon: String
    var color: Color
    var label: String
    var sub: String?
    var size: String
    @Binding var checked: Bool
    var action: () -> Void = {}

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Toggle(isOn: $checked) { EmptyView() }
                    .toggleStyle(CmpCheckboxStyle(accent: theme.accent.color))

                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.18))
                    CmpIcon(name: icon, size: 17, color: color)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.text1(theme.dark))
                    if let sub {
                        Text(sub).font(.system(size: 11.5)).foregroundColor(.text3(theme.dark))
                    }
                }
                Spacer()
                Text(size).font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.text1(theme.dark))
                CmpIcon(name: "chevron", size: 14, color: .text3(theme.dark))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(hover ? Color.black.opacity(0.025) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct CmpCheckboxStyle: ToggleStyle {
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(configuration.isOn ? accent : Color.black.opacity(0.25), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(configuration.isOn ? accent : .clear)
                    )
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 6/255, green: 32/255, blue: 24/255))
                }
            }
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
    }
}
