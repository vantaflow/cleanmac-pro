import SwiftUI
import CleanCore

struct DashboardScreen: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState

    private var storageSlices: [SunburstSlice] {
        let cleanupSize = totalGB(of: .cleanup)
        let filesSize = totalGB(of: .files)
        let free = max(diskTotal - diskUsed, 0)
        return [
            .init(key: "system", label: "Système",      value: 32, color: .cmpViolet),
            .init(key: "apps",   label: "Applications", value: 84, color: .cmpInfo),
            .init(key: "docs",   label: "Documents",    value: 42, color: .cmpWarn),
            .init(key: "photos", label: "Photos",       value: 30.6, color: Color(red: 255/255, green: 159/255, blue: 10/255)),
            .init(key: "clean",  label: "À nettoyer",   value: max(cleanupSize + filesSize, 0.5), color: theme.accent.color),
            .init(key: "free",   label: "Libre",        value: free, color: Color(white: 0.88)),
        ]
    }

    private var diskUsed: Double {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? NSNumber,
              let free = attrs[.systemFreeSize] as? NSNumber
        else { return 207 }
        return (total.doubleValue - free.doubleValue) / 1_000_000_000
    }
    private var diskTotal: Double {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? NSNumber
        else { return 482 }
        return total.doubleValue / 1_000_000_000
    }

    private func totalGB(of module: ModuleID) -> Double {
        Double(appState.state(for: module).result?.totalSize ?? 0) / 1_000_000_000
    }

    private var healthScore: Int {
        var score = 100
        if let sec = appState.state(for: .security).result {
            score -= sec.items.filter { $0.severity == .bad }.count * 8
            score -= sec.items.filter { $0.severity == .warn }.count * 3
        }
        if let upd = appState.state(for: .updates).result {
            score -= min(15, upd.items.filter { $0.severity == .bad }.count * 5)
        }
        let cleanupGB = totalGB(of: .cleanup) + totalGB(of: .files)
        if cleanupGB > 20 { score -= 10 }
        else if cleanupGB > 5 { score -= 4 }
        return max(0, min(100, score))
    }

    private let weeklyData: [DayValue] = [
        .init(day: "Lu", value: 1.2), .init(day: "Ma", value: 0.4),
        .init(day: "Me", value: 2.8), .init(day: "Je", value: 0.8),
        .init(day: "Ve", value: 3.4), .init(day: "Sa", value: 0.2),
        .init(day: "Di", value: 5.1),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenHeader(
                    kicker: kicker,
                    title: "Ton Mac va bien.",
                    subtitle: "Lance un Smart Scan pour voir ce qu'il y a à récupérer."
                ) {
                    Btn(kind: .primary, size: .lg, icon: "scan", label: "Lancer Smart Scan") {
                        appState.active = .smartScan
                        let modules: [ModuleID] = [.cleanup, .files, .security, .updates, .privacy]
                        modules.forEach { appState.startScan(module: $0) }
                    }
                }

                // Hero panel
                GlassPanel(radius: 16, padding: 24) {
                    HStack(alignment: .center, spacing: 32) {
                        // Sunburst
                        VStack(spacing: 10) {
                            Text("STOCKAGE · 482 GO")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(.text3(theme.dark))
                            StorageSunburst(size: 200,
                                            slices: storageSlices,
                                            used: diskUsed,
                                            total: diskTotal,
                                            defaultKey: "clean")
                            SunburstLegend(slices: storageSlices).padding(.top, 4)
                        }
                        .frame(width: 240)

                        // Health ring
                        VStack(spacing: 10) {
                            Text("SANTÉ").font(.system(size: 10, weight: .semibold))
                                .tracking(0.8).foregroundColor(.text3(theme.dark))
                            Ring(size: 190, stroke: 12, value: Double(healthScore), color: theme.accent.color) {
                                VStack(spacing: 0) {
                                    Text("\(healthScore)")
                                        .font(.system(size: 52, weight: .bold))
                                        .tracking(-2)
                                        .foregroundColor(.text1(theme.dark))
                                    Text("sur 100").font(.system(size: 11))
                                        .foregroundColor(.text3(theme.dark))
                                }
                            }
                            HStack(spacing: 6) {
                                StatusPill(status: cpuStatus, text: "CPU")
                                StatusPill(status: diskStatus, text: "Disque")
                                StatusPill(status: .good, text: "Sécurité")
                            }
                        }
                        .frame(width: 220)

                        // Mini stats
                        VStack(spacing: 8) {
                            MiniStat(icon: "broom", color: theme.accent.color,
                                     label: "Récupérables maintenant",
                                     value: ByteFormatter.string(Int64(totalGB(of: .cleanup) * 1_000_000_000)),
                                     sub: "caches, logs, apps dormantes") {
                                appState.active = .cleanup
                            }
                            MiniStat(icon: "ram", color: .cmpViolet,
                                     label: "Mémoire active",
                                     value: ramStat,
                                     sub: "top processus") {
                                appState.active = .performance
                            }
                            MiniStat(icon: "shield", color: Color(red: 191/255, green: 90/255, blue: 242/255),
                                     label: "Traceurs identifiés",
                                     value: trackerCount,
                                     sub: "Safari, Chrome, Firefox") {
                                appState.active = .privacy
                            }
                            MiniStat(icon: "bolt", color: .cmpWarn,
                                     label: "Apps au démarrage",
                                     value: loginItemCount,
                                     sub: "ralentit le démarrage") {
                                appState.active = .performance
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Trend + AI insight
                HStack(spacing: 12) {
                    WeeklyTrend(data: weeklyData).frame(maxWidth: .infinity)
                    aiInsight.frame(maxWidth: 360)
                }

                // Module cards grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ModuleCard(icon: "broom", color: .cmpWarn, title: "Fichiers inutiles",
                               stat: cleanupBadge, sub: "Caches, logs, anciens téléchargements") {
                        appState.active = .cleanup
                    }
                    ModuleCard(icon: "app", color: .cmpInfo, title: "Désinstalleur",
                               stat: uninstallerBadge, sub: "Apps + résidus") {
                        appState.active = .uninstaller
                    }
                    ModuleCard(icon: "disk", color: theme.accent.color, title: "Space Lens",
                               stat: spaceLensBadge, sub: "Carte interactive du disque") {
                        appState.active = .spaceLens
                    }
                    ModuleCard(icon: "shield", color: .cmpWarn, title: "Sécurité",
                               stat: securityBadge, sub: "Anti-malware, FileVault") {
                        appState.active = .security
                    }
                    ModuleCard(icon: "arrow", color: .cmpBad, title: "Mises à jour",
                               stat: updatesBadge, sub: "Apps, brew, macOS") {
                        appState.active = .updates
                    }
                    ModuleCard(icon: "bolt", color: .cmpViolet, title: "Performance",
                               stat: perfBadge, sub: "Démarrage + agents") {
                        appState.active = .performance
                    }
                    ModuleCard(icon: "eye", color: Color(red: 191/255, green: 90/255, blue: 242/255),
                               title: "Confidentialité", stat: privacyBadge,
                               sub: "Cookies, traceurs") { appState.active = .privacy }
                    ModuleCard(icon: "files", color: Color(red: 255/255, green: 159/255, blue: 10/255),
                               title: "Volumineux & doublons", stat: filesBadge,
                               sub: "+ doublons") { appState.active = .files }
                    ModuleCard(icon: "wrench", color: .cmpGood, title: "Maintenance",
                               stat: maintBadge, sub: "DNS, reindex, RAM") {
                        appState.active = .maintenance
                    }
                }
                .padding(.bottom, 60)
            }
            .frame(maxWidth: 1080)
            .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: – derived strings

    private var kicker: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEEE d MMMM"
        return "Bonjour — \(fmt.string(from: Date()))"
    }

    private var cleanupBadge: String {
        let s = appState.state(for: .cleanup)
        if let r = s.result, !r.items.isEmpty { return ByteFormatter.string(r.totalSize) }
        return "—"
    }
    private var filesBadge: String {
        let s = appState.state(for: .files)
        if let r = s.result, !r.items.isEmpty { return "\(r.count)" }
        return "—"
    }
    private var uninstallerBadge: String {
        let s = appState.state(for: .uninstaller)
        if let r = s.result {
            let apps = r.items.filter { $0.kind == .app }.count
            return "\(apps) apps"
        }
        return "—"
    }
    private var spaceLensBadge: String {
        let s = appState.state(for: .spaceLens)
        if let r = s.result, !r.items.isEmpty { return ByteFormatter.string(r.totalSize) }
        return "Scanner"
    }
    private var securityBadge: String {
        let s = appState.state(for: .security)
        guard let r = s.result else { return "—" }
        let bad = r.items.filter { $0.severity == .bad }.count
        let warn = r.items.filter { $0.severity == .warn }.count
        if bad + warn == 0 { return "OK" }
        return "\(bad + warn) alerte\(bad + warn > 1 ? "s" : "")"
    }
    private var updatesBadge: String {
        let s = appState.state(for: .updates)
        guard let r = s.result else { return "—" }
        let count = r.items.filter { $0.severity != .good }.count
        return count == 0 ? "À jour" : "\(count)"
    }
    private var perfBadge: String {
        let s = appState.state(for: .performance)
        guard let r = s.result else { return "—" }
        return "\(r.items.filter { $0.kind == .loginItem || $0.kind == .launchAgent }.count) au démarrage"
    }
    private var privacyBadge: String {
        let s = appState.state(for: .privacy)
        guard let r = s.result else { return "—" }
        return "\(r.items.count) navigateur\(r.items.count > 1 ? "s" : "")"
    }
    private var maintBadge: String {
        let s = appState.state(for: .maintenance)
        guard let r = s.result else { return "6 tâches" }
        return "\(r.items.count) tâches"
    }

    private var ramStat: String {
        let perf = appState.state(for: .performance).result
        let top = perf?.items.filter { $0.kind == .processSnapshot }
            .reduce(Int64(0)) { $0 + $1.size } ?? 0
        return ByteFormatter.string(top)
    }
    private var trackerCount: String {
        guard let r = appState.state(for: .privacy).result, !r.items.isEmpty else { return "—" }
        return "\(r.items.count) sources"
    }
    private var loginItemCount: String {
        guard let r = appState.state(for: .performance).result else { return "—" }
        let n = r.items.filter { $0.kind == .loginItem }.count
        return "\(n) actives"
    }

    private var cpuStatus: PillStatus {
        guard let r = appState.state(for: .performance).result else { return .info }
        return r.items.contains(where: { $0.kind == .processSnapshot && $0.severity == .warn }) ? .warn : .good
    }
    private var diskStatus: PillStatus {
        let cleanup = totalGB(of: .cleanup) + totalGB(of: .files)
        if cleanup > 20 { return .warn }
        return .good
    }

    private var aiInsight: some View {
        // Real insight derived from local scanner state — no LLM needed.
        GlassPanel(radius: 12, padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(theme.accent.color.opacity(0.18))
                    CmpIcon(name: "sparkle", size: 18, color: theme.accent.color)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("INSIGHT").font(.system(size: 10, weight: .semibold))
                        .tracking(0.8).foregroundColor(.text3(theme.dark))
                    Text(insightMessage)
                        .font(.system(size: 13)).foregroundColor(.text1(theme.dark))
                        .lineLimit(2)
                }
                Spacer()
            }
        }
        .background(
            LinearGradient(colors: [theme.accent.color.opacity(0.1), theme.accent.color.opacity(0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
    }

    private var insightMessage: String {
        let cleanup = totalGB(of: .cleanup)
        let files = totalGB(of: .files)
        let total = cleanup + files
        if total > 1 {
            return "Boom. Tu peux récupérer \(String(format: "%.1f", total)) Go en nettoyant les caches et les gros fichiers."
        }
        if appState.state(for: .cleanup).result == nil {
            return "Lance un Smart Scan pour voir où récupérer de l'espace."
        }
        return "Ton Mac est propre. Bon point."
    }
}
