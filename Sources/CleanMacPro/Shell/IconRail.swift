import SwiftUI
import CleanCore

/// CleanMyMac 5 module taxonomy, per-module color identity, sidebar icons.
extension ModuleID {
    /// Display name used in the sidebar + big screen title.
    var railTitle: String {
        switch self {
        case .smartScan:   return "Entretien intelligent"
        case .cleanup:     return "Nettoyage"
        case .security:    return "Protection"
        case .performance: return "Performances"
        case .uninstaller: return "Applications"
        case .files:       return "Mes fichiers inutiles"
        case .spaceLens:   return "Télescope"
        case .privacy:     return "Confidentialité"
        case .updates:     return "Mises à jour"
        case .maintenance: return "Maintenance"
        default:           return title
        }
    }

    /// Flat SF Symbol shown in the sidebar (CleanMyMac 5 uses simple glyphs).
    var railSymbol: String {
        switch self {
        case .smartScan:   return "desktopcomputer"
        case .cleanup:     return "sparkles"
        case .security:    return "hand.raised.fill"
        case .performance: return "bolt.fill"
        case .uninstaller: return "square.grid.2x2.fill"
        case .files:       return "folder.fill"
        case .spaceLens:   return "circle.circle.fill"
        case .privacy:     return "eye.fill"
        case .updates:     return "arrow.down.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        default:           return "square"
        }
    }

    /// Full color identity — background, glow and accent.
    var theme: ModuleTheme {
        switch self {
        case .smartScan, .dashboard, .result:
            return ModuleTheme(bgTop: c(0.20,0.06,0.33), bgBottom: c(0.44,0.16,0.56),
                               glow: c(0.72,0.30,0.86), accent: c(0.78,0.36,0.95))
        case .cleanup:
            return ModuleTheme(bgTop: c(0.05,0.15,0.09), bgBottom: c(0.15,0.38,0.22),
                               glow: c(0.30,0.75,0.42), accent: c(0.32,0.78,0.44))
        case .security:
            return ModuleTheme(bgTop: c(0.22,0.05,0.15), bgBottom: c(0.55,0.12,0.36),
                               glow: c(0.90,0.24,0.60), accent: c(0.92,0.28,0.62))
        case .performance:
            return ModuleTheme(bgTop: c(0.20,0.09,0.03), bgBottom: c(0.58,0.26,0.09),
                               glow: c(0.98,0.56,0.20), accent: c(0.98,0.58,0.22))
        case .uninstaller:
            return ModuleTheme(bgTop: c(0.06,0.10,0.26), bgBottom: c(0.16,0.30,0.64),
                               glow: c(0.30,0.55,1.0), accent: c(0.32,0.56,0.98))
        case .files:
            return ModuleTheme(bgTop: c(0.05,0.16,0.16), bgBottom: c(0.14,0.38,0.36),
                               glow: c(0.28,0.74,0.68), accent: c(0.28,0.74,0.68))
        case .spaceLens:
            return ModuleTheme(bgTop: c(0.11,0.06,0.30), bgBottom: c(0.30,0.18,0.72),
                               glow: c(0.46,0.32,0.96), accent: c(0.46,0.32,0.96))
        case .privacy:
            return ModuleTheme(bgTop: c(0.21,0.06,0.14), bgBottom: c(0.52,0.16,0.34),
                               glow: c(0.94,0.36,0.58), accent: c(0.94,0.36,0.58))
        case .updates:
            return ModuleTheme(bgTop: c(0.06,0.10,0.26), bgBottom: c(0.16,0.30,0.64),
                               glow: c(0.30,0.55,1.0), accent: c(0.32,0.56,0.98))
        case .maintenance:
            return ModuleTheme(bgTop: c(0.20,0.09,0.03), bgBottom: c(0.58,0.26,0.09),
                               glow: c(0.98,0.56,0.20), accent: c(0.98,0.58,0.22))
        }
    }

    /// Closest built-in accent so shared controls (buttons, checkboxes,
    /// progress) pick up the module hue.
    var accentEnum: Accent {
        switch self {
        case .cleanup, .files:                       return .mint
        case .uninstaller, .updates, .spaceLens:     return .blue
        case .security, .privacy, .smartScan,
             .dashboard, .result:                    return .violet
        case .performance, .maintenance:             return .orange
        }
    }

    /// Hero-glyph gradient stops (lighter → darker of the module accent).
    var glyphTint: [Color] {
        let a = theme.accent
        return [a.opacity(0.95), a.opacity(0.55)]
    }

    private func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
}

/// CleanMyMac 5 labeled sidebar: icon + text, translucent dark panel, the
/// selected row gets a rounded tinted highlight.
struct IconRail: View {
    @EnvironmentObject var appState: AppState

    private let primary: [ModuleID] = [
        .smartScan, .cleanup, .security, .performance,
        .uninstaller, .files, .spaceLens
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 58) // traffic-light clearance
            VStack(spacing: 4) {
                ForEach(primary) { m in
                    SidebarRow(module: m,
                               selected: appState.active == m,
                               badge: badge(for: m),
                               action: { appState.active = m })
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Assistant / settings row (opens the live menu-bar panel).
            SidebarRow(module: nil, icon: "bubbles.and.sparkles.fill", label: "Assistant",
                       selected: false, badge: false,
                       action: { appState.menubarOpen.toggle() })
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
        }
        .frame(width: 264)
        .background(Color.black.opacity(0.22))
    }

    private func badge(for m: ModuleID) -> Bool {
        (appState.state(for: m).result?.items.isEmpty == false)
    }
}

private struct SidebarRow: View {
    var module: ModuleID?
    var icon: String? = nil
    var label: String? = nil
    let selected: Bool
    let badge: Bool
    let action: () -> Void
    @State private var hover = false

    private var symbol: String { icon ?? module?.railSymbol ?? "square" }
    private var text: String { label ?? module?.railTitle ?? "" }
    private var accent: Color { module?.theme.accent ?? .white }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(selected ? .white : .white.opacity(0.62))
                    .frame(width: 24, height: 24)
                Text(text)
                    .font(.system(size: 14.5, weight: selected ? .semibold : .medium))
                    .foregroundColor(selected ? .white : .white.opacity(0.82))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if badge {
                    Circle().fill(Color(red: 1, green: 0.42, blue: 0.42))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.white.opacity(0.14)
                                   : (hover ? Color.white.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
