import SwiftUI
import Darwin
import Darwin.Mach
import CleanCore

struct MenubarWidget: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    // Live host stats refreshed every 2 s.
    @State private var cpuPct: Double = 0
    @State private var ramUsedGB: Double = 0
    @State private var ramTotalGB: Double = 0
    @State private var diskUsedGB: Double = 0
    @State private var diskTotalGB: Double = 1
    @State private var refreshTimer: Timer? = nil

    private var recoverableLabel: String {
        let bytes = appState.state(for: .cleanup).result?.totalSize ?? 0
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
                Button { appState.menubarOpen = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 8)

            HStack(spacing: 8) {
                Meter(label: "CPU", value: cpuPct, max: 100, unit: "%", color: .cmpInfo)
                Meter(label: "RAM", value: ramUsedGB, max: ramTotalGB, unit: "Go", color: .cmpViolet)
                Meter(label: "Disque", value: diskUsedGB, max: diskTotalGB, unit: "Go", color: theme.accent.color)
            }

            // Spark / activity strip (decorative sparkline)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Activité système").font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                    Spacer()
                    Text("CPU \(Int(cpuPct))% · RAM \(String(format: "%.1f", ramUsedGB)) Go")
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(0.5)
                }
                Spark(accent: theme.accent.color)
                    .frame(height: 28)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(spacing: 2) {
                QuickAction(icon: "scan", label: "Lancer Smart Scan",
                            sub: "Tout vérifier", accent: true) {
                    appState.menubarOpen = false
                    appState.active = .smartScan
                    [.cleanup, .files, .security, .updates, .privacy].forEach {
                        appState.startScan(module: $0)
                    }
                }
                QuickAction(icon: "ram", label: "Libérer la RAM",
                            sub: "\(String(format: "%.1f", ramUsedGB)) / \(String(format: "%.0f", ramTotalGB)) Go utilisés") {
                    _ = Shell.run("/usr/sbin/purge", [])
                }
                QuickAction(icon: "trash", label: "Vider la corbeille",
                            sub: "Demande confirmation système") {
                    let script = "tell application \"Finder\" to empty the trash"
                    _ = Shell.run("/usr/bin/osascript", ["-e", script])
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                Button {
                    appState.menubarOpen = false
                    appState.active = .dashboard
                } label: {
                    Text("Ouvrir CleanMac Pro →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accent.color)
                }
                .buttonStyle(.plain)
                Spacer()
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
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .onAppear(perform: startRefreshing)
        .onDisappear { refreshTimer?.invalidate(); refreshTimer = nil }
        .preferredColorScheme(.dark)
    }

    private func startRefreshing() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in refresh() }
    }
    private func refresh() {
        // RAM
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let pageBytes = Double(pageSize)
            let active = Double(vmStats.active_count) * pageBytes
            let wired  = Double(vmStats.wire_count)   * pageBytes
            let comp   = Double(vmStats.compressor_page_count) * pageBytes
            ramUsedGB = (active + wired + comp) / 1_000_000_000
        }
        var total: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &sz, nil, 0)
        ramTotalGB = Double(total) / 1_000_000_000

        // CPU (simple — load average %)
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        cpuPct = min(100, load[0] * 100 / Double(ProcessInfo.processInfo.activeProcessorCount))

        // Disk
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? NSNumber,
           let free = attrs[.systemFreeSize] as? NSNumber {
            diskTotalGB = total.doubleValue / 1_000_000_000
            diskUsedGB = (total.doubleValue - free.doubleValue) / 1_000_000_000
        }
    }
}

private struct Meter: View {
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
                Text(formatted(value))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(-0.3)
                Text(unit == "%" ? "%" : "/\(formatted(max)) \(unit)")
                    .font(.system(size: 10)).opacity(0.5)
            }
            Capsule().fill(Color.white.opacity(0.08))
                .overlay(
                    GeometryReader { geo in
                        Capsule().fill(color).frame(width: geo.size.width * pct)
                    }
                )
                .frame(height: 3)
        }
        .padding(8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
    private func formatted(_ v: Double) -> String {
        v >= 100 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

private struct QuickAction: View {
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
                Image(systemName: "chevron.right").font(.system(size: 10))
                    .opacity(0.4)
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

private struct Spark: View {
    let accent: Color
    @State private var phase: CGFloat = 0
    let bars: [CGFloat] = (0..<32).map { i in
        let s = (sin(Double(i) * 1.3) * 0.5 + 0.5)
        return CGFloat(s * 0.7 + 0.2 + (i > 22 ? 0.15 : 0))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / 32
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(bars.enumerated()), id: \.offset) { i, v in
                    let h = geo.size.height * (v * (0.7 + 0.3 * sin(phase + CGFloat(i) * 0.3)))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent.opacity(0.4 + Double(v) * 0.5))
                        .frame(width: max(2, w - 3), height: max(2, h))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
