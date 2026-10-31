import SwiftUI
import CleanCore

extension PermissionKind {
    var title: String {
        switch self {
        case .fullDiskAccess: return L("Accès complet au disque")
        case .notifications:  return L("Notifications")
        case .automation:     return L("Automatisation (System Events)")
        }
    }
    var reason: String {
        switch self {
        case .fullDiskAccess: return L("Pour voir l'historique Safari, Mail et les caches protégés. Sans lui, certains éléments restent invisibles.")
        case .notifications:  return L("Pour te prévenir quand un scan planifié a trouvé de l'espace à récupérer.")
        case .automation:     return L("Pour lister les éléments de connexion dans Performances.")
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

/// One line per permission: icon, why, state (green check when granted) and the button
/// that requests it or opens the right System Settings pane.
struct PermissionRow: View {
    let kind: PermissionKind
    var onDark = false
    @ObservedObject private var center = PermissionCenter.shared

    private var status: PermissionStatus { center.status(kind) }
    private var primary: Color { onDark ? .white : .primary }
    private var secondary: Color { onDark ? .white.opacity(0.6) : .secondary }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16))
                .frame(width: 34, height: 34)
                .background(Circle().fill(primary.opacity(0.10)))
                .foregroundColor(primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.system(size: 13, weight: .semibold)).foregroundColor(primary)
                Text(kind.reason).font(.system(size: 11.5)).foregroundColor(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status == .granted {
                Label(L("Accordée"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cmpGood)
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status == .denied ? L("Refusée") : L("Pas encore demandée"))
                        .font(.system(size: 11)).foregroundColor(status == .denied ? .cmpBad : secondary)
                    Button(buttonLabel) { center.act(on: kind) }
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var buttonLabel: String {
        switch (kind, status) {
        case (.notifications, .notDetermined), (.automation, .notDetermined): return L("Autoriser")
        default: return L("Ouvrir les Réglages Système")
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
            }
        }
        .formStyle(.grouped)
        .onAppear { center.refresh() }
    }
}
