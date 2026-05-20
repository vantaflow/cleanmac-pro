import SwiftUI
import CleanCore

struct SidebarEntry: Identifiable {
    var id: ModuleID { module }
    let module: ModuleID
    let icon: String
    let label: String
    let badge: String?
    let badgeColor: Color?
}

struct SidebarSection: Identifiable {
    let id = UUID()
    let label: String?
    let entries: [SidebarEntry]
}

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private var sections: [SidebarSection] {
        [
            SidebarSection(label: nil, entries: [
                .init(module: .dashboard, icon: "dashboard", label: "Vue d'ensemble", badge: nil, badgeColor: nil),
                .init(module: .smartScan, icon: "scan", label: "Smart Scan", badge: nil, badgeColor: nil),
            ]),
            SidebarSection(label: "Nettoyer", entries: [
                .init(module: .cleanup, icon: "broom", label: "Fichiers inutiles",
                      badge: dynamicBadge(for: .cleanup), badgeColor: .cmpWarn),
                .init(module: .uninstaller, icon: "app", label: "Désinstalleur",
                      badge: dynamicBadge(for: .uninstaller), badgeColor: .cmpInfo),
                .init(module: .files, icon: "files", label: "Volumineux & doublons",
                      badge: dynamicBadge(for: .files), badgeColor: nil),
                .init(module: .spaceLens, icon: "disk", label: "Space Lens", badge: nil, badgeColor: nil),
            ]),
            SidebarSection(label: "Protéger", entries: [
                .init(module: .security, icon: "shield", label: "Sécurité",
                      badge: dynamicBadge(for: .security), badgeColor: .cmpWarn),
                .init(module: .privacy, icon: "eye", label: "Confidentialité",
                      badge: dynamicBadge(for: .privacy), badgeColor: nil),
            ]),
            SidebarSection(label: "Optimiser", entries: [
                .init(module: .updates, icon: "arrow", label: "Mises à jour",
                      badge: dynamicBadge(for: .updates), badgeColor: .cmpBad),
                .init(module: .performance, icon: "bolt", label: "Performance",
                      badge: nil, badgeColor: nil),
                .init(module: .maintenance, icon: "wrench", label: "Maintenance",
                      badge: nil, badgeColor: nil),
            ]),
        ]
    }

    private func dynamicBadge(for module: ModuleID) -> String? {
        let s = appState.state(for: module)
        guard let result = s.result, !result.items.isEmpty else { return nil }
        if module == .cleanup || module == .files {
            return ByteFormatter.string(result.totalSize)
        }
        return "\(result.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 9) {
                CmpLogo(size: 22, accent: theme.accent.color)
                VStack(alignment: .leading, spacing: -2) {
                    Text("CleanMac")
                        .font(.system(size: 13.5, weight: .bold))
                        .tracking(-0.15)
                        .foregroundColor(.text1(theme.dark))
                    Text("PRO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(.text3(theme.dark))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 36)
            .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 1) {
                            if let label = section.label {
                                Text(label.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundColor(.text3(theme.dark))
                                    .padding(.horizontal, 10).padding(.bottom, 6).padding(.top, 4)
                            }
                            ForEach(section.entries) { entry in
                                SidebarItem(entry: entry,
                                            isSelected: appState.active == entry.module,
                                            action: { appState.active = entry.module })
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 236)
        .background(
            Color.sidebar(theme.dark)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.hairline(theme.dark)).frame(width: 0.5)
        }
    }
}

private struct SidebarItem: View {
    @Environment(\.theme) private var theme
    let entry: SidebarEntry
    let isSelected: Bool
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CmpIcon(name: entry.icon, size: 16,
                        color: isSelected ? theme.accent.onAccent : .text2(theme.dark))
                Text(entry.label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.accent.onAccent : .text1(theme.dark))
                Spacer()
                if let badge = entry.badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(
                            isSelected
                                ? AnyShapeStyle(Color.black.opacity(0.15))
                                : AnyShapeStyle((entry.badgeColor ?? .black).opacity(0.13))
                        )
                        .foregroundColor(isSelected ? theme.accent.onAccent : (entry.badgeColor ?? .text2(theme.dark)))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AnyShapeStyle(theme.accent.color)
                : (hover ? AnyShapeStyle(Color.black.opacity(0.05)) : AnyShapeStyle(Color.clear))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
