import SwiftUI

enum BtnKind { case primary, secondary, ghost, danger, dark }
enum BtnSize {
    case sm, md, lg, xl
    var height: CGFloat { switch self { case .sm: 28; case .md: 34; case .lg: 44; case .xl: 52 } }
    var hPad: CGFloat   { switch self { case .sm: 12; case .md: 16; case .lg: 24; case .xl: 40 } }
    var font: CGFloat   { switch self { case .sm: 12.5; case .md: 13.5; case .lg: 15; case .xl: 17 } }
}

/// Pill button. `primary` fills with the screen accent.
struct Btn: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var enabled
    var kind: BtnKind = .primary
    var size: BtnSize = .md
    var icon: String? = nil
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { CmpIcon(name: icon, size: size.font + 1) }
                Text(label).lineLimit(1)
            }
            .font(.system(size: size.font, weight: size == .xl ? .bold : .semibold))
            .padding(.horizontal, size.hPad)
            .frame(height: size.height)
            .background(Capsule().fill(background))
            .foregroundColor(foreground)
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var background: Color {
        switch kind {
        case .primary:   return theme.accent.color
        case .secondary: return .clear
        case .ghost:     return .clear
        case .danger:    return Color.cmpBad.opacity(0.14)
        case .dark:      return Color.raised(theme.dark)
        }
    }
    private var foreground: Color {
        switch kind {
        case .primary: return theme.accent.onAccent
        case .secondary, .ghost, .dark: return Color.text1(theme.dark)
        case .danger: return .cmpBad
        }
    }
    private var stroke: Color {
        switch kind {
        case .secondary: return Color.strongBorder(theme.dark)
        case .danger:    return Color.cmpBad.opacity(0.3)
        default: return .clear
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Square checkbox in the screen accent. `mixed` shows a dash (partial selection).
struct CmpCheckbox: View {
    @Environment(\.theme) private var theme
    @Binding var isOn: Bool
    var mixed: Bool = false
    var accent: Color? = nil
    var label: String = ""

    var body: some View {
        let tint = accent ?? theme.accent.color
        let filled = isOn || mixed
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(filled ? tint : Color.clear)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(filled ? tint : Color.text3(theme.dark), lineWidth: 1.3)
                if mixed && !isOn {
                    Capsule().fill(Color.black.opacity(0.75)).frame(width: 8, height: 2)
                } else if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color.black.opacity(0.78))
                }
            }
            .frame(width: 18, height: 18)
            .animation(.easeOut(duration: 0.12), value: filled)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "1" : (mixed ? "-" : "0"))
    }
}

struct CmpCheckboxStyle: ToggleStyle {
    var accent: Color
    func makeBody(configuration: Configuration) -> some View {
        CmpCheckbox(isOn: configuration.$isOn, accent: accent)
    }
}
