import Foundation
import SwiftUI
import CleanCore

@MainActor
final class AppState: ObservableObject {
    @Published var theme = Theme()
    @Published var active: ModuleID = .dashboard {
        didSet { if oldValue != active { searchText = "" } }
    }
    @Published var moduleStates: [ModuleID: ModuleState] = [:]
    @Published var menubarOpen = false
    @Published var showOnboarding: Bool
    /// Live filter applied to the active module's results listing.
    @Published var searchText: String = ""

    /// Shared live host metrics for the menu-bar popover / in-window widget.
    let hostStats = HostStats()

    /// Scheduled background scans, notifications, menu-bar-only mode.
    let background = BackgroundAgent()

    /// Modules that render a filterable results list (so the toolbar search
    /// applies). Dashboard / Smart Scan / Space Lens / Result don't.
    func isSearchable(_ module: ModuleID) -> Bool {
        ![.dashboard, .smartScan, .spaceLens, .result].contains(module)
    }

    /// Case-insensitive filter over name, detail, path and group.
    func filter(_ items: [ScanItem]) -> [ScanItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.name.lowercased().contains(q)
            || (item.detail?.lowercased().contains(q) ?? false)
            || item.url.path.lowercased().contains(q)
            || (item.group?.lowercased().contains(q) ?? false)
        }
    }

    init() {
        let seen = UserDefaults.standard.bool(forKey: "ai.turkeycode.cleanmacpro.onboarding.seen")
        self.showOnboarding = !seen
        for m in ModuleID.allCases {
            moduleStates[m] = ModuleState()
        }
    }

    func dismissOnboarding() {
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "ai.turkeycode.cleanmacpro.onboarding.seen")
    }

    /// Runs an executable maintenance task; surfaces status via the module status string.
    func runMaintenance(item: ScanItem) {
        guard item.command != nil else { return }
        update(.maintenance) { $0.status = "Exécution de « \(item.title ?? "tâche") »…" }
        Task.detached(priority: .utility) { [weak self] in
            let (status, output) = MaintenanceScanner.execute(item)
            await MainActor.run { [weak self] in
                self?.update(.maintenance) { s in
                    s.status = status == 0
                        ? "✓ « \(item.title ?? "tâche") » terminée"
                        : "⚠ Échec — \(output.prefix(120))"
                }
            }
        }
    }

    /// "Quick Clean" — cleans every module that has a scan result with safe defaults.
    /// If nothing has been scanned, runs a Smart Scan first.
    func quickClean() {
        let cleanable: [ModuleID] = [.cleanup, .files, .privacy]
        let alreadyScanned = cleanable.contains { moduleStates[$0]?.result != nil }

        guard alreadyScanned else {
            active = .smartScan
            [.cleanup, .files, .security, .updates, .privacy].forEach { startScan(module: $0) }
            return
        }
        for m in cleanable {
            guard let result = moduleStates[m]?.result, !result.items.isEmpty else { continue }
            update(m) { $0.selection = Set(result.items.map(\.id)) }
            clean(module: m)
        }
        active = .result
    }

    func state(for module: ModuleID) -> ModuleState {
        moduleStates[module] ?? ModuleState()
    }

    func update(_ module: ModuleID, _ transform: (inout ModuleState) -> Void) {
        var s = moduleStates[module] ?? ModuleState()
        transform(&s)
        moduleStates[module] = s
    }

    func scanner(for module: ModuleID) -> (any FileScanner)? {
        switch module {
        case .cleanup:     return CleanupScanner()
        case .files:       return FilesScanner()
        case .uninstaller: return AppUninstaller()
        case .security:    return SecurityScanner()
        case .privacy:     return PrivacyScanner()
        case .updates:     return UpdatesScanner()
        case .performance: return PerformanceScanner()
        case .maintenance: return MaintenanceScanner()
        case .spaceLens:   return SpaceLensScanner()
        case .smartScan:   return SmartScanner()     // cleanup + files + privacy + posture, in parallel
        case .dashboard, .result: return nil
        }
    }

    func startScan(module: ModuleID) {
        guard let scanner = scanner(for: module) else { return }
        update(module) { s in
            s.isScanning = true
            s.progress = 0
            s.status = "Démarrage…"
            s.result = nil
            s.selection.removeAll()
        }
        let task = Task.detached(priority: .utility) { [weak self] in
            do {
                let result = try await scanner.scan(progress: { p, msg in
                    Task { @MainActor [weak self] in
                        self?.update(module) { s in
                            s.progress = p
                            s.status = msg
                        }
                    }
                })
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.result = result
                        s.status = "\(result.count) éléments · \(ByteFormatter.string(result.totalSize))"
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.status = "Annulé"
                    }
                }
            }
        }
        update(module) { $0.currentTask = task }
    }

    func cancelScan(module: ModuleID) {
        moduleStates[module]?.currentTask?.cancel()
        update(module) { s in
            s.isScanning = false
            s.status = "Annulé"
        }
    }

    /// - Parameter permanent: when true (Uninstaller), removes items outright
    ///   instead of trashing, so a removed .app never lingers in the Trash
    ///   where other cleaners detect it and nag.
    func clean(module: ModuleID, permanent: Bool = false) {
        let state = self.state(for: module)
        guard let result = state.result, !state.selection.isEmpty else { return }
        let toClean = result.items.filter { state.selection.contains($0.id) }
            .filter { ![.securityFinding, .updateAvailable, .loginItem, .launchAgent,
                        .processSnapshot, .maintenanceTask, .spaceFolder].contains($0.kind) }

        let report = permanent ? Cleaner.delete(items: toClean) : Cleaner.clean(items: toClean)
        applyClean(module: module, report: report)

        // Items that failed are usually root-owned (App Store apps like Xcode).
        // Retry with an admin prompt, off the main thread so the UI doesn't
        // freeze during authentication.
        let needAdmin = toClean.filter { report.failedItems.contains($0.url) }
        guard !needAdmin.isEmpty else { return }
        update(module) { $0.status = "Authentification requise pour \(needAdmin.count) élément(s)…" }
        Task.detached(priority: .userInitiated) { [weak self] in
            let adminReport = permanent
                ? Cleaner.deleteWithAdmin(items: needAdmin)
                : Cleaner.trashWithAdmin(items: needAdmin)
            await MainActor.run { [weak self] in
                self?.applyClean(module: module, report: adminReport, appendFreed: report.freedBytes)
            }
        }
    }

    /// Removes successfully-cleaned items from the module result and reports.
    private func applyClean(module: ModuleID, report: CleanReport, appendFreed: Int64 = 0) {
        update(module) { s in
            s.lastReport = report
            s.result?.items.removeAll { !report.failedItems.contains($0.url) && s.selection.contains($0.id) }
            let freed = report.freedBytes + appendFreed
            if report.failedItems.isEmpty {
                s.selection.removeAll()
                s.status = "Libéré \(ByteFormatter.string(freed))"
            } else {
                s.status = "Libéré \(ByteFormatter.string(freed)) · \(report.failedItems.count) échec(s)"
            }
        }
    }
}

struct ModuleState {
    var isScanning: Bool = false
    var progress: Double = 0
    var status: String = "Prêt"
    var result: ScanResult? = nil
    var selection: Set<UUID> = []
    var lastReport: CleanReport? = nil
    var currentTask: Task<Void, Never>? = nil
    var sortKey: SortKey = .size
    var sortDescending: Bool = true
}

enum SortKey: String, CaseIterable, Identifiable {
    case size, name, modified
    var id: String { rawValue }
    var label: String {
        switch self {
        case .size: return "Taille"
        case .name: return "Nom"
        case .modified: return "Date"
        }
    }
    var symbol: String {
        switch self {
        case .size: return "ram"
        case .name: return "files"
        case .modified: return "scan"
        }
    }
}
