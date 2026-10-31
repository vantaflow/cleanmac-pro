import SwiftUI
import AppKit
import CleanCore

/// Content of the menu-bar popover (and of the in-window preview).
/// Every row does something real: run / start Smart Care, jump to updates,
/// empty the Trash (with confirmation), toggle the scheduled scan, open the app.
struct MenuPanelContent: View {
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stats: HostStats
    @EnvironmentObject var agent: BackgroundAgent

    var onDismiss: (() -> Void)? = nil
    @State private var trashBytes: Int64 = 0

    /// Reopen / focus the single main window, recreating it if it was closed.
    private func openMain() {
        onDismiss?()
        AppDelegate.current?.popover?.performClose(nil)
        if let open = WindowOpener.shared.open {
            open()
        } else {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var plan: SmartCarePlan { appState.smartCarePlan }
    private var hasPlan: Bool { appState.smartCare.phase == .results }
    private var recoverable: Int64 {
        if hasPlan { return plan.regenerableBytes }
        return agent.lastRecoverableBytes
    }
    private var updatesCount: Int { plan.updates.count }

    private var statusText: String {
        if agent.isScanning || appState.smartCare.phase == .scanning { return L("Analyse en cours…") }
        return recoverable > 0 ? L("\(ByteFormatter.string(recoverable)) à libérer") : L("Tout va bien")
    }

    var body: some View {
        let dark = true
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                CmpLogo(size: 32, accent: Accent.mint.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CleanMac Pro").font(.system(size: 14, weight: .semibold))
                    Text(statusText).font(.system(size: 12)).foregroundColor(Accent.mint.soft)
                }
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.text3(dark)).padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                MenuMeter(label: "CPU", value: "\(Int(stats.cpuPct)) %", fraction: stats.cpuPct / 100, color: Accent.blue.color)
                MenuMeter(label: L("MÉMOIRE"),
                          value: "\(Int(stats.ramUsedGB.rounded()))/\(Int(stats.ramTotalGB.rounded()))",
                          fraction: stats.ramTotalGB > 0 ? stats.ramUsedGB / stats.ramTotalGB : 0, color: Accent.violet.color)
                MenuMeter(label: L("DISQUE"),
                          value: appState.disk.map { ByteFormatter.string($0.freeBytes) } ?? "—",
                          fraction: appState.disk?.usedFraction ?? 0, color: Accent.mint.color)
            }

            VStack(spacing: 2) {
                if hasPlan && plan.hasWork {
                    MenuAction(title: L("Libérer \(ByteFormatter.string(plan.runnablePermanentBytes)) maintenant"),
                               sub: L("Caches, temporaires et journaux"),
                               trailing: L("Lancer"), highlighted: true) {
                        openMain()
                        appState.navigate(to: .smartScan)
                        appState.runSmartCare()
                    }
                } else {
                    MenuAction(title: L("Analyser mon Mac"),
                               sub: L("Nettoyage, sécurité, performances, applications"),
                               trailing: L("Analyser"), highlighted: true) {
                        openMain()
                        appState.navigate(to: .smartScan)
                        appState.startSmartCare()
                    }
                }
                if hasPlan && updatesCount > 0 {
                    MenuAction(title: L("\(Int(updatesCount)) mise(s) à jour"), sub: L("Voir les applications à mettre à jour"), trailing: "›") {
                        openMain()
                        appState.review(.updates)
                    }
                }
                MenuAction(title: L("Vider la Corbeille"),
                           sub: trashBytes > 0 ? L("\(ByteFormatter.string(trashBytes)) · confirmation avant suppression")
                                               : L("La Corbeille est vide"),
                           trailing: "›", enabled: trashBytes > 0) {
                    appState.emptyTrash()
                    refreshTrash()
                }
            }

            VStack(spacing: 10) {
                MenuToggleRow(label: L("Analyse planifiée"), isOn: $agent.scheduledScanEnabled)
                MenuToggleRow(label: L("Barre de menus seule"), isOn: $agent.menuBarOnly)
                MenuToggleRow(label: L("Lancer au démarrage"), isOn: $agent.launchAtLogin)
            }
            .padding(12)
            .cardSurface(dark: dark, radius: Radius.m, fill: Color.sidebarBg(dark))

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Button(action: openMain) {
                    Text(L("Ouvrir CleanMac Pro")).font(.system(size: 13, weight: .semibold)).foregroundColor(Accent.mint.soft)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Text(L("Réglages")).font(.system(size: 13)).foregroundColor(.text2(dark))
                }
                .buttonStyle(.plain)
                Button { AppLifecycle.shared.quit() } label: {
                    Text(L("Quitter")).font(.system(size: 13)).foregroundColor(.text2(dark))
                }
                .buttonStyle(.plain)
                Text(verbatim: "v\(appVersion)").font(.system(size: 11)).foregroundColor(.text3(dark))
            }
        }
        .padding(16)
        .frame(width: 360, height: 520)
        .background(Color.card(dark))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.strongBorder(dark), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundColor(.text1(dark))
        .preferredColorScheme(.dark)
        .onAppear { stats.start(); appState.refreshDisk(); refreshTrash() }
        .onDisappear { stats.stop() }
    }

    private func refreshTrash() {
        Task.detached(priority: .utility) {
            let size = FS.directorySize(FS.home.appendingPathComponent(".Trash"))
            await MainActor.run { trashBytes = size }
        }
    }
}

// MARK: — Shared subviews

struct MenuMeter: View {
    let label: String
    let value: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundColor(.text3(true))
            Text(value).font(.figure(18, .bold)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundColor(.text1(true))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.track(true))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(max(0.02, min(1, fraction))))
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(dark: true, radius: 11, fill: Color.sidebarBg(true))
    }
}

struct MenuAction: View {
    let title: String
    let sub: String
    var trailing: String
    var highlighted = false
    var enabled = true
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.text1(true))
                    Text(sub).font(.system(size: 12)).foregroundColor(.text2(true)).lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(trailing).font(.system(size: highlighted ? 13 : 16, weight: .bold))
                    .foregroundColor(highlighted ? Accent.mint.color : .text3(true))
            }
            .padding(.horizontal, 10)
            .frame(height: highlighted ? 52 : 48)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(highlighted ? Color.raised(true) : (hover ? Color.raised(true).opacity(0.5) : .clear)))
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hover = $0 }
    }
}

struct MenuToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.textSoft(true))
            Spacer()
            CmpCheckbox(isOn: $isOn, accent: Accent.mint.color, label: label)
        }
    }
}

private var appVersion: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
}
