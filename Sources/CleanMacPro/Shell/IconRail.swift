import SwiftUI
import CleanCore

/// CleanMyMac 5 module taxonomy + hero styling for each rail entry.
extension ModuleID {
    /// Display name used for the immersive centered title bar.
    var railTitle: String {
        switch self {
        case .smartScan:   return "Smart Care"
        case .cleanup:     return "Nettoyage"
        case .security:    return "Protection"
        case .performance: return "Performances"
        case .uninstaller: return "Applications"
        case .files:       return "Mes fichiers"
        case .spaceLens:   return "Télescope"
        case .privacy:     return "Confidentialité"
        case .updates:     return "Mises à jour"
        case .maintenance: return "Maintenance"
        default:           return title
        }
    }

    /// Glossy hero-glyph gradient stops.
    var glyphTint: [Color] {
        switch self {
        case .smartScan:   return [Color(red: 0.36, green: 0.80, blue: 0.78), Color(red: 0.14, green: 0.52, blue: 0.68)]
        case .cleanup:     return [Color(red: 0.42, green: 0.62, blue: 1.0),  Color(red: 0.18, green: 0.30, blue: 0.85)]
        case .security:    return [Color(red: 0.36, green: 0.82, blue: 0.55), Color(red: 0.12, green: 0.52, blue: 0.40)]
        case .performance: return [Color(red: 1.0,  green: 0.66, blue: 0.34), Color(red: 0.86, green: 0.36, blue: 0.20)]
        case .uninstaller: return [Color(red: 0.55, green: 0.55, blue: 1.0),  Color(red: 0.28, green: 0.24, blue: 0.78)]
        case .files:       return [Color(red: 0.72, green: 0.52, blue: 1.0),  Color(red: 0.44, green: 0.24, blue: 0.82)]
        case .spaceLens:   return [Color(red: 0.36, green: 0.72, blue: 0.98), Color(red: 0.16, green: 0.42, blue: 0.80)]
        case .privacy:     return [Color(red: 1.0,  green: 0.52, blue: 0.72), Color(red: 0.78, green: 0.26, blue: 0.50)]
        case .updates:     return [Color(red: 0.40, green: 0.70, blue: 1.0),  Color(red: 0.18, green: 0.40, blue: 0.86)]
        case .maintenance: return [Color(red: 0.58, green: 0.66, blue: 0.80), Color(red: 0.30, green: 0.38, blue: 0.55)]
        default:           return [Color(red: 0.55, green: 0.62, blue: 0.95), Color(red: 0.30, green: 0.34, blue: 0.72)]
        }
    }
}

struct IconRail: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme

    /// CleanMyMac 5 order.
    private let entries: [ModuleID] = [
        .smartScan, .cleanup, .security, .performance,
        .uninstaller, .files, .spaceLens, .privacy, .updates, .maintenance
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 64) // clears the traffic-light / title zone
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(entries) { module in
                        RailButton(
                            module: module,
                            selected: appState.active == module,
                            badge: badge(for: module),
                            action: { appState.active = module }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            Spacer(minLength: 8)
            SettingsDot(action: { appState.menubarOpen.toggle() })
                .padding(.bottom, 16)
        }
        .frame(width: 78)
    }

    private func badge(for module: ModuleID) -> Bool {
        let s = appState.state(for: module)
        return (s.result?.items.isEmpty == false)
    }
}

private struct RailButton: View {
    let module: ModuleID
    let selected: Bool
    let badge: Bool
    var glyphOverride: String? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.22), lineWidth: 0.8))
                        .frame(width: 54, height: 54)
                } else if hover {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 54, height: 54)
                }
                ModuleGlyph(symbol: glyphOverride ?? module.symbol, size: 38, tint: module.glyphTint)
                    .saturation(selected ? 1 : 0.9)
                    .opacity(selected ? 1 : 0.92)
                if badge {
                    Circle().fill(Color(red: 1, green: 0.42, blue: 0.42))
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                        .offset(x: 17, y: -17)
                }
            }
            .frame(width: 58, height: 58)
            .overlay(alignment: .trailing) {
                if selected {
                    Capsule().fill(Color.white)
                        .frame(width: 3, height: 22)
                        .offset(x: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .help(module.railTitle)
        .onHover { hover = $0 }
    }
}

private struct SettingsDot: View {
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(hover ? 1 : 0.7))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(hover ? 0.12 : 0.06)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
