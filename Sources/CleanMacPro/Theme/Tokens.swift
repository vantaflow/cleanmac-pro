import SwiftUI

enum Accent: String, CaseIterable, Identifiable {
    case mint, blue, violet, orange
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .mint:   return Color(red: 0/255,   green: 217/255, blue: 163/255)
        case .blue:   return Color(red: 10/255,  green: 132/255, blue: 255/255)
        case .violet: return Color(red: 191/255, green: 90/255,  blue: 242/255)
        case .orange: return Color(red: 255/255, green: 159/255, blue: 10/255)
        }
    }

    /// Text color when used as a button background (dark variant of accent)
    var onAccent: Color {
        switch self {
        case .mint:   return Color(red: 6/255,  green: 32/255, blue: 24/255)
        case .blue:   return Color(red: 2/255,  green: 22/255, blue: 58/255)
        case .violet: return Color(red: 27/255, green: 10/255, blue: 48/255)
        case .orange: return Color(red: 42/255, green: 21/255, blue: 5/255)
        }
    }
}

enum Wallpaper: String, CaseIterable, Identifiable {
    case macpaw, aurora, graphite, sunset, forest
    var id: String { rawValue }

    var stops: [Color] {
        switch self {
        case .macpaw:
            // CleanMyMac 5 immersive violet → blue.
            return [
                Color(red: 108/255, green: 92/255,  blue: 231/255),
                Color(red: 74/255,  green: 63/255,  blue: 176/255),
                Color(red: 45/255,  green: 79/255,  blue: 200/255)
            ]
        case .aurora:
            return [
                Color(red: 43/255, green: 58/255, blue: 95/255),
                Color(red: 20/255, green: 24/255, blue: 43/255),
                Color(red: 6/255,  green: 8/255,  blue: 15/255)
            ]
        case .graphite:
            return [
                Color(red: 42/255, green: 42/255, blue: 46/255),
                Color(red: 24/255, green: 24/255, blue: 27/255),
                Color(red: 10/255, green: 10/255, blue: 12/255)
            ]
        case .sunset:
            return [
                Color(red: 90/255, green: 42/255, blue: 62/255),
                Color(red: 42/255, green: 21/255, blue: 37/255),
                Color(red: 12/255, green: 6/255,  blue: 18/255)
            ]
        case .forest:
            return [
                Color(red: 29/255, green: 58/255, blue: 48/255),
                Color(red: 14/255, green: 32/255, blue: 24/255),
                Color(red: 4/255,  green: 16/255, blue: 12/255)
            ]
        }
    }
}

enum Density: String, CaseIterable, Identifiable {
    case compact, regular, comfy
    var id: String { rawValue }
    var baseFontSize: CGFloat {
        switch self {
        case .compact: return 13.5
        case .regular: return 14
        case .comfy:   return 15
        }
    }
}

struct Theme {
    var accent: Accent = .violet
    var dark: Bool = true
    var density: Density = .regular
    var wallpaper: Wallpaper = .macpaw
}

// MARK: — Immersive (CleanMyMac 5) styling

extension Wallpaper {
    /// Full-bleed diagonal gradient used behind the immersive shell.
    var immersiveGradient: LinearGradient {
        LinearGradient(
            colors: stops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    /// Frosted translucent card, à la CleanMyMac 5 content surfaces.
    func immersiveCard(radius: CGFloat = 28) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Color.white.opacity(0.06))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: — Semantic colors

extension Color {
    static let cmpGood = Color(red: 52/255,  green: 199/255, blue: 89/255)
    static let cmpWarn = Color(red: 255/255, green: 176/255, blue: 32/255)
    static let cmpBad  = Color(red: 255/255, green: 69/255,  blue: 58/255)
    static let cmpInfo = Color(red: 10/255,  green: 132/255, blue: 255/255)
    static let cmpViolet = Color(red: 94/255, green: 92/255, blue: 230/255)

    static func text1(_ dark: Bool) -> Color { dark ? Color(white: 245/255) : Color(red: 29/255, green: 29/255, blue: 31/255) }
    static func text2(_ dark: Bool) -> Color { (dark ? Color(white: 245/255) : Color(red: 29/255, green: 29/255, blue: 31/255)).opacity(dark ? 0.6 : 0.62) }
    static func text3(_ dark: Bool) -> Color { (dark ? Color(white: 245/255) : Color(red: 29/255, green: 29/255, blue: 31/255)).opacity(dark ? 0.4 : 0.42) }

    static func hairline(_ dark: Bool) -> Color { dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }
    static func hairlineSoft(_ dark: Bool) -> Color { dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05) }

    static func panel(_ dark: Bool) -> Color { dark ? Color.white.opacity(0.05) : Color.white.opacity(0.78) }
    static func panelSolid(_ dark: Bool) -> Color { dark ? Color(red: 35/255, green: 35/255, blue: 40/255) : Color.white }

    static func sidebar(_ dark: Bool) -> Color {
        dark ? Color(red: 22/255, green: 24/255, blue: 32/255).opacity(0.6)
             : Color(red: 232/255, green: 235/255, blue: 242/255).opacity(0.55)
    }

    static func windowBg(_ dark: Bool) -> Color {
        dark ? Color(red: 28/255, green: 28/255, blue: 32/255) : Color(red: 246/255, green: 246/255, blue: 248/255)
    }
}

// MARK: — Environment-injected theme

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
