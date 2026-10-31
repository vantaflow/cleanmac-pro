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
private enum PermPalette {
    static let card = Color(red: 0x15/255, green: 0x19/255, blue: 0x22/255)
    static let border = Color(red: 0x23/255, green: 0x27/255, blue: 0x33/255)
    static let borderGranted = Color(red: 0x1F/255, green: 0x5E/255, blue: 0x54/255)
    static let accent = Color(red: 0x2B/255, green: 0xC4/255, blue: 0xA9/255)
    static let accentText = Color(red: 0x7F/255, green: 0xE3/255, blue: 0xD0/255)
    static let text = Color(red: 0xF2/255, green: 0xF4/255, blue: 0xF8/255)
    static let muted = Color(red: 0xA9/255, green: 0xB0/255, blue: 0xBE/255)
    static let pill = Color(red: 0xE8/255, green: 0xEC/255, blue: 0xF3/255)
    static let ink = Color(red: 0x0D/255, green: 0x0F/255, blue: 0x14/255)

    static func iconBg(_ k: PermissionKind) -> Color {
        switch k {
        case .fullDiskAccess: return Color(red: 0x12/255, green: 0x3A/255, blue: 0x35/255)
        case .notifications:  return Color(red: 0x16/255, green: 0x29/255, blue: 0x4A/255)
        case .automation:     return Color(red: 0x3A/255, green: 0x2C/255, blue: 0x10/255)
        }
    }
    static func iconFg(_ k: PermissionKind) -> Color {
        switch k {
        case .fullDiskAccess: return accent
        case .notifications:  return Color(red: 0x9E/255, green: 0xC0/255, blue: 0xFF/255)
        case .automation:     return Color(red: 0xF5/255, green: 0xC4/255, blue: 0x6B/255)
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
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.28)))
            .overlay(Capsule().stroke(Color.cmpWarn.opacity(0.5), lineWidth: 0.8))
            .padding(.horizontal, 28).padding(.top, 12)
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
