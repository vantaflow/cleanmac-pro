import SwiftUI

enum BtnKind { case primary, secondary, ghost, danger, dark }
enum BtnSize {
    case sm, md, lg
    var height: CGFloat { switch self { case .sm: 28; case .md: 34; case .lg: 42 } }
    var hPad: CGFloat   { switch self { case .sm: 12; case .md: 16; case .lg: 22 } }
    var font: CGFloat   { switch self { case .sm: 12.5; case .md: 13.5; case .lg: 15 } }
    var radius: CGFloat { switch self { case .sm: 7; case .md: 9; case .lg: 11 } }
}

struct Btn: View {
    @Environment(\.theme) private var theme
    var kind: BtnKind = .primary
    var size: BtnSize = .md
    var icon: String? = nil
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { CmpIcon(name: icon, size: size.font + 2) }
                Text(label)
            }
            .font(.system(size: size.font, weight: .semibold))
            .padding(.horizontal, size.hPad)
            .frame(height: size.height)
            .background(background)
            .foregroundColor(foreground)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: size.radius))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var background: Color {
        switch kind {
        case .primary:   return theme.accent.color
        case .secondary: return Color.black.opacity(theme.dark ? 0.25 : 0.06)
        case .ghost:     return .clear
        case .danger:    return Color.cmpBad.opacity(0.12)
        case .dark:      return Color.black.opacity(0.85)
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary: return theme.accent.onAccent
        case .secondary, .ghost: return Color.text1(theme.dark)
        case .danger: return .cmpBad
        case .dark:   return .white
        }
    }
    @ViewBuilder private var border: some View {
        let stroke: Color = {
            switch kind {
            case .secondary: return Color.hairline(theme.dark)
            case .danger:    return Color.cmpBad.opacity(0.25)
            default: return .clear
            }
        }()
        RoundedRectangle(cornerRadius: size.radius).stroke(stroke, lineWidth: 0.5)
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
