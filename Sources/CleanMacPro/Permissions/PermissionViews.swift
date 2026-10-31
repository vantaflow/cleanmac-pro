import SwiftUI
import CleanCore

extension PermissionKind {
    var title: String {
        switch self {
        case .fullDiskAccess: return L("Accès complet au disque")
        case .notifications:  return L("Notifications")
        case .automation:     return L("Automatisation (Événements système)")
        }
    }
    var reason: String {
        switch self {
        case .fullDiskAccess: return L("Caches protégés, Safari, Mail, restes d'apps")
        case .notifications:  return L("Scans planifiés et apps supprimées détectées")
        case .automation:     return L("Lister les éléments ouverts au démarrage")
        }
    }
    var symbol: String {
        switch self {
        case .fullDiskAccess: return "internaldrive"
        case .notifications:  return "bell.badge"
        case .automation:     return "gearshape.2"
        }
    }
}

/// Local palette for the permission cards (matches the onboarding mock-up).
/// Maps the permission views onto the shared design tokens (Theme/Tokens.swift).
private enum PermPalette {
    static let card = Color.adaptive(0x151922, 0xFFFFFF)
    static let border = Color.adaptive(0x232733, 0xDCDFE7)
    static let borderGranted = Color.adaptive(0x1F5E54, 0x8FD9C9)
    static let accent = Accent.mint.color
    static let accentText = Accent.mint.soft
    static let text = Color.adaptive(0xF2F4F8, 0x14161B)
    static let muted = Color.adaptive(0xA9B0BE, 0x565D6C)
    static let pill = Color.adaptive(0xE8ECF3, 0x14161B)
    static let ink = Color.adaptive(0x0D0F14, 0xFFFFFF)

    static func iconBg(_ k: PermissionKind) -> Color {
        switch k {
        case .fullDiskAccess: return Accent.mint.tint
        case .notifications:  return Accent.blue.tint
        case .automation:     return Accent.amber.tint
        }
    }
    static func iconFg(_ k: PermissionKind) -> Color {
        switch k {
        case .fullDiskAccess: return accent
        case .notifications:  return Accent.blue.soft
        case .automation:     return Accent.amber.soft
        }
    }
}

/// One permission: icon, why, and either the button that requests it / opens the right
/// System Settings pane, or a green « Accordé » check. `card` = dark onboarding card style.
struct PermissionRow: View {
    let kind: PermissionKind
    var card = false
    @ObservedObject private var center = PermissionCenter.shared

    private var status: PermissionStatus { center.status(kind) }
    private var granted: Bool { status == .granted }

    var body: some View {
        let row = HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: card ? 40 : 34, height: card ? 40 : 34)
                .background(RoundedRectangle(cornerRadius: 11).fill(card ? PermPalette.iconBg(kind) : Color.primary.opacity(0.10)))
                .foregroundColor(card ? PermPalette.iconFg(kind) : .primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title).font(.system(size: card ? 15 : 13, weight: .semibold))
                    .foregroundColor(card ? PermPalette.text : .primary)
                Text(kind.reason).font(.system(size: card ? 13 : 11.5))
                    .foregroundColor(card ? PermPalette.muted : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text(L("Accordé")).font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(card ? PermPalette.accentText : .cmpGood)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    if status == .denied {
                        Text(L("Refusée")).font(.system(size: 11)).foregroundColor(.cmpBad)
                    }
                    if card {
                        Button(action: { center.act(on: kind) }) {
                            Text(buttonLabel)
                                .font(.system(size: 13.5, weight: .bold))
                                .padding(.horizontal, 16).frame(height: 38)
                                .background(Capsule().fill(PermPalette.pill))
                                .foregroundColor(PermPalette.ink)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(buttonLabel) { center.act(on: kind) }.controlSize(.small)
                    }
                }
            }
        }
        if card {
            row.padding(.horizontal, 18).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(PermPalette.card))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(granted ? PermPalette.borderGranted : PermPalette.border, lineWidth: 1))
        } else {
            row.padding(.vertical, 6)
        }
    }

    private var buttonLabel: String {
        switch (kind, status) {
        case (.notifications, .notDetermined), (.automation, .notDetermined): return L("Autoriser")
        default: return L("Ouvrir les Réglages")
        }
    }
}

/// Discreet bar shown on Privacy / Cleanup / Files when Full Disk Access is missing.
struct PermissionBanner: View {
    let module: ModuleID
    @ObservedObject private var center = PermissionCenter.shared

    var body: some View {
        if PermissionNeeds.needsFullDiskAccess(module),
           center.status(.fullDiskAccess) == .denied, !center.bannerDismissed {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield").font(.system(size: 14))
                Text(L("Certains éléments sont invisibles sans l'accès complet au disque"))
                    .font(.system(size: 12.5, weight: .medium))
                Spacer(minLength: 8)
                Button(L("Accorder l'accès")) { center.openSettings(.fullDiskAccess) }
                    .controlSize(.small)
                Button { center.bannerDismissed = true } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help(L("Masquer"))
            }
            .foregroundColor(PermPalette.text)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(PermPalette.card))
            .overlay(Capsule().strokeBorder(Color.cmpWarn.opacity(0.5), lineWidth: 0.8))
            .padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 6)
            .zIndex(1)
            .transition(.opacity)
        }
    }
}

/// « Autorisations » tab of the Settings window.
struct PermissionsSettings: View {
    @ObservedObject private var center = PermissionCenter.shared

    var body: some View {
        Form {
            Section {
                ForEach(PermissionKind.allCases, id: \.self) { PermissionRow(kind: $0) }
            } footer: {
                Text(L("L'état se met à jour tout seul quand tu reviens dans l'app. Si l'accès complet au disque n'apparaît pas tout de suite, quitte et relance CleanMac Pro. Après une mise à jour, macOS peut te le redemander : l'app est signée sans certificat d'identité stable, il suffit de le réactiver."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .formStyle(.grouped)
        .onAppear { center.refresh() }
    }
}
