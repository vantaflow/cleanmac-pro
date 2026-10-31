import SwiftUI
import AppKit

// MARK: — Design system
//
// One palette, one scale. Graphite surfaces, a single accent hue per
// category, system typography with tabular figures, pill buttons. Every
// screen draws from these tokens; no view hard-codes a color or a radius.

/// Category accents (one hue per area of the app).
enum Accent: String, CaseIterable, Identifiable {
    case mint, blue, amber, violet, coral, cyan, pink, slate
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .mint:   return .adaptive(0x2BC4A9, 0x14A88F)   // Nettoyage
        case .blue:   return .adaptive(0x4C8DFF, 0x3478F0)   // Protection
        case .amber:  return .adaptive(0xF5A524, 0xE08E0B)   // Performances
        case .violet: return .adaptive(0x9B7BFF, 0x8463F2)   // Applications
        case .coral:  return .adaptive(0xFF7A59, 0xF0623F)   // Encombrement
        case .cyan:   return .adaptive(0x4FB6E8, 0x2A9BD3)   // Développeur
        case .pink:   return .adaptive(0xE56BB0, 0xD4549C)   // Télescope
        case .slate:  return .adaptive(0xA9B0BE, 0x7C8394)   // Historique
        }
    }

    /// Text variant of the accent (links, kickers): lighter on the dark canvas,
    /// deeper on the light one so it keeps a readable contrast.
    var soft: Color {
        switch self {
        case .mint:   return .adaptive(0x7FE3D0, 0x0B7A67)
        case .blue:   return .adaptive(0x9EC0FF, 0x1F5FD1)
        case .amber:  return .adaptive(0xFFCF7A, 0x95590A)
        case .violet: return .adaptive(0xC4B3FF, 0x5F41CC)
        case .coral:  return .adaptive(0xFFAE96, 0xB9472A)
        case .cyan:   return .adaptive(0x9ADAF7, 0x17739F)
        case .pink:   return .adaptive(0xF3A6D2, 0xA83677)
        case .slate:  return .adaptive(0xC4CAD6, 0x4A5160)
        }
    }

    /// Tinted chip background (icon tiles, pills), dark or pale per appearance.
    var tint: Color {
        switch self {
        case .mint:   return .adaptive(0x123A35, 0xDAF4EE)
        case .blue:   return .adaptive(0x16294A, 0xE0EBFF)
        case .amber:  return .adaptive(0x3F2D0E, 0xFCEFD6)
        case .violet: return .adaptive(0x2A2147, 0xEBE5FF)
        case .coral:  return .adaptive(0x3D1F17, 0xFFE6DE)
        case .cyan:   return .adaptive(0x12323F, 0xDCF0F9)
        case .pink:   return .adaptive(0x3F1B30, 0xFAE2F0)
        case .slate:  return .adaptive(0x262B36, 0xE6E8EE)
        }
    }

    /// Ink used on top of a solid accent fill (primary buttons).
    var onAccent: Color {
        switch self {
        case .mint:   return Color(hex: 0x06231E)
        case .blue:   return Color(hex: 0x04152F)
        case .amber:  return Color(hex: 0x2A1B02)
        case .violet: return Color(hex: 0x15093A)
        case .coral:  return Color(hex: 0x2E0F05)
        case .cyan:   return Color(hex: 0x04202C)
        case .pink:   return Color(hex: 0x2E0A1F)
        case .slate:  return Color(hex: 0x14161B)
        }
    }
}

struct Theme {
    var accent: Accent = .mint
    /// Effective appearance. Never set by hand: `.themed(_:)` derives it from the
    /// window's real color scheme (which follows `AppState.appearance`).
    var dark: Bool = true
}

/// User choice in Réglages › Apparence. Applied app-wide through `NSApp.appearance`,
/// so the main window, Settings, the menu-bar popover and floating panels all agree.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("Système")
        case .light:  return L("Clair")
        case .dark:   return L("Sombre")
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    private static func pick(_ dark: Bool, _ d: UInt32, _ l: UInt32) -> Color { Color(hex: dark ? d : l) }

    /// A color that resolves itself against the appearance it is drawn in
    /// (dark value, light value). Used where no `theme` is at hand: static
    /// palettes, accents, floating panels.
    static func adaptive(_ d: UInt32, _ l: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? d : l
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    // Surfaces
    static func canvas(_ dark: Bool) -> Color      { pick(dark, 0x0D0F14, 0xF4F5F8) }
    static func sidebarBg(_ dark: Bool) -> Color   { pick(dark, 0x12151C, 0xEBEDF2) }
    static func card(_ dark: Bool) -> Color        { pick(dark, 0x151922, 0xFFFFFF) }
    static func cardBorder(_ dark: Bool) -> Color  { pick(dark, 0x232733, 0xDCDFE7) }
    static func strongBorder(_ dark: Bool) -> Color { pick(dark, 0x2C3240, 0xC9CED9) }
    static func raised(_ dark: Bool) -> Color      { pick(dark, 0x1E2430, 0xE2E5EC) }
    static func inset(_ dark: Bool) -> Color       { pick(dark, 0x171B23, 0xF0F2F6) }
    static func track(_ dark: Bool) -> Color       { pick(dark, 0x262B36, 0xDDE0E8) }
    static func rowLine(_ dark: Bool) -> Color     { pick(dark, 0x1E232D, 0xE8EAF0) }

    // Text
    static func text1(_ dark: Bool) -> Color { pick(dark, 0xF2F4F8, 0x14161B) }
    static func text2(_ dark: Bool) -> Color { pick(dark, 0xA9B0BE, 0x565D6C) }
    static func text3(_ dark: Bool) -> Color { pick(dark, 0x8A91A1, 0x7C8394) }
    static func textSoft(_ dark: Bool) -> Color { pick(dark, 0xC4CAD6, 0x3A404D) }

    // Semantic
    static let cmpGood = Color(hex: 0x34C759)
    static let cmpWarn = Color(hex: 0xFFB020)
    static let cmpBad  = Color(hex: 0xFF5A52)
    static let cmpInfo = Color(hex: 0x4C8DFF)
    static let cmpViolet = Color(hex: 0x9B7BFF)

    // Legacy names (kept so every older view picks up the new palette).
    static func hairline(_ dark: Bool) -> Color { cardBorder(dark) }
    static func hairlineSoft(_ dark: Bool) -> Color { rowLine(dark) }
    static func panel(_ dark: Bool) -> Color { card(dark) }
    static func panelSolid(_ dark: Bool) -> Color { card(dark) }
    static func sidebar(_ dark: Bool) -> Color { sidebarBg(dark) }
    static func windowBg(_ dark: Bool) -> Color { canvas(dark) }
}

/// Spacing scale.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii.
enum Radius {
    static let s: CGFloat = 8
    static let m: CGFloat = 10
    static let l: CGFloat = 14
}

extension Font {
    /// System font with tabular figures: sizes, percentages and counters never jitter.
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

// MARK: — Per-module identity

struct ModuleTheme {
    var accentCase: Accent
    var accent: Color { accentCase.color }
}

// MARK: — Surfaces

extension View {
    /// The standard card: graphite fill, 1 px border, optional accent border or dashed outline.
    func cardSurface(dark: Bool, radius: CGFloat = Radius.l,
                     border: Color? = nil, dashed: Bool = false, fill: Color? = nil) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill ?? Color.card(dark)))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border ?? Color.cardBorder(dark),
                                  style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 4] : []))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: — Environment-injected theme

/// Injects `\.theme` with `dark` taken from the real color scheme of the view
/// (so "Système" follows macOS live, and "Clair"/"Sombre" follow NSApp.appearance).
private struct ThemeBridge: ViewModifier {
    @ObservedObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        var t = state.theme
        t.dark = scheme == .dark
        return content.environment(\.theme, t)
    }
}

extension View {
    @MainActor func themed(_ state: AppState) -> some View { modifier(ThemeBridge(state: state)) }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
