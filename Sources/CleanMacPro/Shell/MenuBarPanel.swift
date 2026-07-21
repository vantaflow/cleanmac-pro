import SwiftUI
import AppKit
import CleanCore

/// Shared content for both the in-window widget and the real `MenuBarExtra`
/// popover. `onDismiss` shows an X (in-window only). Opening the main window
/// is handled internally via `openWindow` so it works even after the window
/// has been closed and the app is resident in the menu bar.
struct MenuPanelContent: View {
    @Environment(\.theme) private var theme
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stats: HostStats
    @EnvironmentObject var agent: BackgroundAgent

    var onDismiss: (() -> Void)? = nil

    /// Reopen / focus the single main window, recreating it if it was closed.
    private func openMain() {
        onDismiss?()
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private var recoverableLabel: String {
        // Prefer a fresh in-session scan, else the last remembered total.
        let live = appState.state(for: .cleanup).result?.totalSize ?? 0
        let bytes = live > 0 ? live : agent.lastRecoverableBytes
        if agent.isScanning { return "Analyse en cours…" }
        return bytes == 0 ? "Lance un scan" : "\(ByteFormatter.string(bytes)) récupérables"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                CmpLogo(size: 22, accent: theme.accent.color)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CleanMac Pro").font(.system(size: 12.5, weight: .semibold))
                    Text("Veille active · \(recoverableLabel)")
                        .font(.system(size: 10.5)).opacity(0.55)
                }
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 8)

            HStack(spacing: 8) {
                MenuMeter(label: "CPU", value: stats.cpuPct, max: 100, unit: "%", color: .cmpInfo)
                MenuMeter(label: "RAM", value: stats.ramUsedGB, max: stats.ramTotalGB, unit: "Go", color: .cmpViolet)
                MenuMeter(label: "Disque", value: stats.diskUsedGB, max: stats.diskTotalGB, unit: "Go", color: theme.accent.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Activité système").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                    Spacer()
                    Text("CPU \(Int(stats.cpuPct))% · RAM \(String(format: "%.1f", stats.ramUsedGB)) Go")
                        .font(.system(size: 11, design: .monospaced)).opacity(0.5)
                }
                MenuSpark(samples: stats.cpuHistory, accent: theme.accent.color)
                    .frame(height: 28)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                MenuQuickAction(icon: "scan", label: "Lancer Smart Scan",
                                sub: "Tout vérifier", accent: true) {
                    openMain()
                    appState.active = .smartScan
                    [.cleanup, .files, .security, .updates, .privacy].forEach { appState.startScan(module: $0) }
                }
                MenuQuickAction(icon: "ram", label: "Libérer la RAM",
                                sub: "\(String(format: "%.1f", stats.ramUsedGB)) / \(String(format: "%.0f", stats.ramTotalGB)) Go utilisés") {
                    Task.detached(priority: .utility) { _ = Shell.run("/usr/sbin/purge", []) }
                }
                MenuQuickAction(icon: "trash", label: "Vider la corbeille",
                                sub: "Demande confirmation système") {
                    Task.detached(priority: .utility) {
                        _ = Shell.run("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty the trash"])
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack(spacing: 8) {
                MenuToggle(icon: "clock.arrow.circlepath", label: "Scan auto",
                           isOn: $agent.scheduledScanEnabled, accent: theme.accent.color)
                MenuToggle(icon: "menubar.rectangle", label: "Barre seule",
                           isOn: $agent.menuBarOnly, accent: theme.accent.color)
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                Button {
                    openMain()
                    appState.active = .dashboard
                } label: {
                    Text("Ouvrir CleanMac Pro →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accent.color)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Text("Quitter")
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                Text("v 2.0.0").font(.system(size: 10.5)).opacity(0.4)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(width: 320)
        .background(
            ZStack {
                Color(red: 28/255, green: 28/255, blue: 32/255).opacity(0.92)
                Color.clear.background(.ultraThinMaterial)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }
}

// MARK: — Shared subviews

struct MenuMeter: View {
    let label: String
    let value: Double
    let max: Double
    let unit: String
    let color: Color

    var body: some View {
        let pct = max > 0 ? value / max : 0
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold))
                .tracking(0.6).opacity(0.55)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formatted(value)).font(.system(size: 16, weight: .bold, design: .monospaced)).tracking(-0.3)
                Text(unit == "%" ? "%" : "/\(formatted(max)) \(unit)").font(.system(size: 10)).opacity(0.5)
            }
            Capsule().fill(Color.white.opacity(0.08))
                .overlay(GeometryReader { geo in
                    Capsule().fill(color).frame(width: geo.size.width * pct)
                })
                .frame(height: 3)
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
    private func formatted(_ v: Double) -> String { v >= 100 ? "\(Int(v))" : String(format: "%.1f", v) }
}

struct MenuQuickAction: View {
    let icon: String
    let label: String
    let sub: String
    var accent: Bool = false
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(accent ? Color.cmpGood.opacity(0.16) : Color.white.opacity(0.06))
                    CmpIcon(name: icon, size: 15, color: accent ? .cmpGood : .white)
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).font(.system(size: 12.5, weight: .semibold))
                    Text(sub).font(.system(size: 10.5)).opacity(0.55)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).opacity(0.4)
            }
            .padding(8)
            .background(hover ? Color.white.opacity(0.06) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .foregroundColor(.white)
    }
}

/// Compact pill toggle used in the menu-bar footer.
struct MenuToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let accent: Color

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 11.5, weight: .medium))
                Spacer(minLength: 0)
                Circle()
                    .fill(isOn ? accent : Color.white.opacity(0.18))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(isOn ? accent.opacity(0.16) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isOn ? accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundColor(isOn ? .white : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

/// Real sparkline driven by live CPU samples (no fake animation → no idle work).
struct MenuSpark: View {
    let samples: [Double]
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let n = Swift.max(samples.count, 1)
            let w = geo.size.width / CGFloat(n)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, v in
                    let frac = CGFloat(Swift.min(Swift.max(v / 100, 0.02), 1))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent.opacity(0.35 + Double(frac) * 0.5))
                        .frame(width: Swift.max(2, w - 3), height: Swift.max(2, geo.size.height * frac))
                }
            }
        }
    }
}
