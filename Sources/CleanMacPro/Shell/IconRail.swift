import SwiftUI
import CleanCore

/// Module taxonomy: names, glyphs and the accent hue of each area.
extension ModuleID {
    /// Display name used in the sidebar + big screen title.
    var railTitle: String {
        switch self {
        case .smartScan, .dashboard: return L("Smart Care")
        case .cleanup:     return L("Nettoyage")
        case .security:    return L("Protection")
        case .performance: return L("Performances")
        case .uninstaller: return L("Applications")
        case .files:       return L("Encombrement")
        case .similarPhotos: return L("Photos similaires")
        case .developer:   return L("Développeur")
        case .spaceLens:   return L("Télescope")
        case .privacy:     return L("Confidentialité")
        case .updates:     return L("Mises à jour")
        case .maintenance: return L("Maintenance")
        case .history:     return L("Historique")
        case .result:      return title
        }
    }

    var railSymbol: String {
        switch self {
        case .smartScan, .dashboard: return "checkmark.shield.fill"
        case .cleanup:     return "sparkles"
        case .security:    return "shield.lefthalf.filled"
        case .performance: return "bolt.fill"
        case .uninstaller: return "square.grid.2x2.fill"
        case .files:       return "tray.full.fill"
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .developer:   return "hammer.fill"
        case .spaceLens:   return "circle.circle.fill"
        case .privacy:     return "eye.fill"
        case .updates:     return "arrow.down.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .history:     return "clock.arrow.circlepath"
        case .result:      return "checkmark.circle.fill"
        }
    }

    /// Accent hue of the area this module belongs to.
    var accentEnum: Accent {
        switch self {
        case .smartScan, .dashboard, .cleanup, .result: return .mint
        case .security, .privacy:                      return .blue
        case .performance, .maintenance:               return .amber
        case .uninstaller, .updates:                   return .violet
        case .files, .similarPhotos:                   return .coral
        case .developer:                               return .cyan
        case .spaceLens:                               return .pink
        case .history:                                 return .slate
        }
    }

    var theme: ModuleTheme { ModuleTheme(accentCase: accentEnum) }
}

/// Sidebar: two sections, accent-tinted icon tiles, live disk gauge at the bottom.
struct IconRail: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private let care: [ModuleID] = [.smartScan, .cleanup, .security, .performance, .uninstaller, .files]
    private let tools: [ModuleID] = [.developer, .spaceLens, .history]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer().frame(height: 30) // traffic-light clearance
            section(L("ENTRETIEN"))
            ForEach(care) { m in row(m, tall: true) }
            section(L("OUTILS")).padding(.top, 14)
            ForEach(tools) { m in row(m, tall: false) }
            Spacer(minLength: 12)
            DiskGauge()
        }
        .padding(.horizontal, 12).padding(.bottom, 16)
        .frame(width: 232)
        .frame(maxHeight: .infinity)
        .background(Color.sidebarBg(theme.dark))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.cardBorder(theme.dark)).frame(width: 1)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold)).tracking(0.9)
            .foregroundColor(.text3(theme.dark))
            .padding(.horizontal, 10).padding(.bottom, 4)
    }

    private func row(_ m: ModuleID, tall: Bool) -> some View {
        SidebarRow(module: m, tall: tall,
                   selected: isSelected(m),
                   badge: appState.sidebarBadge(for: m)) {
            appState.navigate(to: m)
        }
    }

    /// Modules grouped under another sidebar entry highlight that entry.
    private func isSelected(_ m: ModuleID) -> Bool {
        let a = appState.active
        switch m {
        case .smartScan:   return a == .smartScan || a == .dashboard || a == .result
        case .security:    return a == .security || a == .privacy
        case .performance: return a == .performance || a == .maintenance
        case .uninstaller: return a == .uninstaller || a == .updates
        case .files:       return a == .files || a == .similarPhotos
        default:           return a == m
        }
    }
}

private struct SidebarRow: View {
    @Environment(\.theme) private var theme
    let module: ModuleID
    let tall: Bool
    let selected: Bool
    let badge: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let dark = theme.dark
        Button(action: action) {
            HStack(spacing: 10) {
                IconChip(symbol: module.railSymbol, accent: module.accentEnum, size: 24)
                    .opacity(selected ? 1 : 0.85)
                Text(module.railTitle)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .text1(dark) : .textSoft(dark))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if badge {
                    Circle().fill(module.accentEnum.color).frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: tall ? 40 : 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.raised(dark) : (hover ? Color.raised(dark).opacity(0.5) : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nav-\(module.rawValue)")
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// "Macintosh HD · 127 Go libres" with a usage bar, from the real volume.
private struct DiskGauge: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    var body: some View {
        let dark = theme.dark
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: DiskSpace.volumeName()).lineLimit(1)
                Spacer()
                if let d = appState.disk {
                    Text(L("\(ByteFormatter.string(d.freeBytes)) libres"))
                } else {
                    Text(verbatim: "—")
                }
            }
            .font(.system(size: 12)).foregroundColor(.text2(dark))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track(dark))
                    Capsule().fill(Color.text1(dark))
                        .frame(width: geo.size.width * CGFloat(appState.disk?.usedFraction ?? 0))
                        .animation(.easeOut(duration: 0.5), value: appState.disk?.usedFraction ?? 0)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .cardSurface(dark: dark, radius: Radius.m, fill: Color.inset(dark))
        .accessibilityElement(children: .combine)
    }
}
