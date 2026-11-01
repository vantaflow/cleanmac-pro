import Foundation
import SwiftUI
import AppKit
import CleanCore

@MainActor
final class AppState: ObservableObject {
    /// Shared instance so the AppKit AppDelegate (status item, popover) and the
    /// SwiftUI scenes operate on the same state.
    static let shared = AppState()

    @Published var theme = Theme()
    /// Réglages › Apparence (Système / Clair / Sombre), persisted. The UI test
    /// switches it without persisting so a local run never changes the user's choice.
    @Published var appearance: Appearance = Appearance(
        rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system {
        didSet {
            if !UITestDriver.isEnabled { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
            applyAppearance()
        }
    }

    func applyAppearance() {
        NSApp?.appearance = appearance.nsAppearance
        // NSPopover keeps the appearance it was first shown with: refresh it explicitly.
        if let pop = AppDelegate.current?.popover, let app = NSApp { pop.appearance = app.effectiveAppearance }
    }
    @Published var active: ModuleID = .smartScan {
        didSet { if oldValue != active { searchText = "" } }
    }
    @Published var moduleStates: [ModuleID: ModuleState] = [:]
    @Published var menubarOpen = false
    @Published var showOnboarding: Bool
    /// Paths / app ids never proposed again (persisted JSON).
    @Published private(set) var exclusions = ExclusionList.load()
    /// Cleanup history with Trash paths, for "Restaurer".
    @Published private(set) var history = CleanHistory.load()
    /// Scheduled-scan LaunchAgent preference.
    @Published private(set) var schedule = ScheduledScanAgent.loadSchedule()
    /// Live filter applied to the active module's results listing.
    @Published var searchText: String = ""
    /// Free space of the startup volume (sidebar gauge, before/after measures).
    @Published private(set) var disk: DiskSnapshot? = DiskSpace.snapshot()
    /// Smart Care flow (home → scanning → results → running).
    @Published var smartCare = SmartCareState()
    /// What the last cleanup really did (Result screen).
    @Published var lastOutcome: CleanOutcome?
    /// True when a module screen was opened from a Smart Care card ("Revoir").
    @Published var cameFromSmartCare = false
    private var smartCareTask: Task<Void, Never>?

    /// Shared live host metrics for the menu-bar popover / in-window widget.
    let hostStats = HostStats()

    /// Scheduled background scans, notifications, menu-bar-only mode.
    let background = BackgroundAgent()

    /// Modules that render a filterable results list (so the toolbar search
    /// applies). Dashboard / Smart Scan / Space Lens / Result don't.
    func isSearchable(_ module: ModuleID) -> Bool {
        ![.dashboard, .smartScan, .spaceLens, .result, .history].contains(module)
    }

    // MARK: — Navigation

    /// Sidebar navigation.
    func navigate(to module: ModuleID) {
        cameFromSmartCare = false
        active = module
    }

    /// Smart Care "Revoir": opens a module with a way back to the results.
    func review(_ module: ModuleID) {
        cameFromSmartCare = true
        active = module
    }

    func backToSmartCare() {
        cameFromSmartCare = false
        active = .smartScan
    }

    /// Dot in the sidebar when an area has something worth a look.
    func sidebarBadge(for module: ModuleID) -> Bool {
        guard let r = moduleStates[module]?.result else { return false }
        switch module {
        case .security:  return r.items.contains { $0.kind == .securityFinding && ($0.severity == .warn || $0.severity == .bad) }
        case .updates:   return r.items.contains { $0.kind == .updateAvailable && $0.severity == .warn }
        default:         return r.items.contains { $0.kind.isCleanable }
        }
    }

    func refreshDisk() { disk = DiskSpace.snapshot() }

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
    func runMaintenance(item: ScanItem, module: ModuleID = .maintenance) {
        guard let command = item.command else { return }
        // Destructive tool commands (Docker prune) ask for confirmation first.
        if command.contains("system prune") {
            let alert = NSAlert()
            alert.messageText = L("Lancer « \(item.title ?? "docker system prune") » ?")
            alert.informativeText = L("Supprime les conteneurs arrêtés, les réseaux et les images inutilisés. Cette action est irréversible.")
            alert.addButton(withTitle: L("Supprimer"))
            alert.addButton(withTitle: L("Annuler"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        update(module) { $0.status = L("Exécution de « \(item.title ?? L("tâche")) »…") }
        Task.detached(priority: .utility) { [weak self] in
            let (status, output) = MaintenanceScanner.execute(item)
            await MainActor.run { [weak self] in
                self?.update(module) { s in
                    s.status = status == 0
                        ? L("✓ « \(item.title ?? L("tâche")) » terminée")
                        : L("⚠ Échec — \(String(output.prefix(120)))")
                }
            }
        }
    }

    /// Updates a Sparkle app in place (after confirmation); falls back to `open -a` when automatic install is impossible.
    func installSparkleUpdate(item: ScanItem) {
        guard let release = item.sparkleRelease else { return runMaintenance(item: item, module: .updates) }
        let name = item.url.deletingPathExtension().lastPathComponent
        let alert = NSAlert()
        alert.messageText = L("Mettre à jour \(name) ?")
        alert.informativeText = L("\(item.title ?? name)\n\nLa mise à jour est téléchargée, vérifiée (signature), puis remplace l'app ; l'ancienne version va à la Corbeille. \(name) doit être fermée.")
        alert.addButton(withTitle: L("Mettre à jour"))
        alert.addButton(withTitle: L("Annuler"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        update(.updates) { $0.status = L("Mise à jour de \(name)…") }
        Task { [weak self] in
            let outcome = await SparkleInstaller.install(appURL: item.url, release: release) { step in
                Task { @MainActor [weak self] in self?.update(.updates) { $0.status = step } }
            }
            guard let self else { return }
            let done = NSAlert()
            switch outcome {
            case .installed:
                done.messageText = L("\(name) est à jour")
                done.informativeText = outcome.message
                self.update(.updates) { $0.status = L("✓ \(name) mis à jour") }
                self.startScan(module: .updates)
            case .manual:
                done.messageText = L("Installation manuelle nécessaire")
                done.informativeText = outcome.message + L("\n\nL'app va être ouverte pour que tu la mettes à jour.")
                self.update(.updates) { $0.status = L("⚠ \(name) : installation manuelle") }
                self.runMaintenance(item: item, module: .updates)
            case .failed:
                done.messageText = L("Échec de la mise à jour de \(name)")
                done.informativeText = outcome.message
                self.update(.updates) { $0.status = L("⚠ Échec — \(String(outcome.message.prefix(120)))") }
            }
            done.runModal()
        }
    }

    func state(for module: ModuleID) -> ModuleState {
        moduleStates[module] ?? ModuleState()
    }

    func update(_ module: ModuleID, _ transform: (inout ModuleState) -> Void) {
        var s = moduleStates[module] ?? ModuleState()
        transform(&s)
        moduleStates[module] = s
    }

    /// UI test mode only: fixture scanners replacing the real ones.
    var scannerOverrides: [ModuleID: any FileScanner] = [:]

    func scanner(for module: ModuleID) -> (any FileScanner)? {
        if let o = scannerOverrides[module] { return o }
        switch module {
        case .cleanup:     return CleanupScanner()
        case .files:       return FilesScanner()
        case .similarPhotos: return SimilarPhotosScanner()
        case .developer:   return DeveloperScanner()
        case .uninstaller: return AppUninstaller()
        case .security:    return SecurityScanner()
        case .privacy:     return PrivacyScanner()
        case .updates:     return UpdatesScanner()
        case .performance: return PerformanceScanner()
        case .maintenance: return MaintenanceScanner()
        case .spaceLens:   return SpaceLensScanner()
        case .smartScan:   return SmartScanner()     // cleanup + files + privacy + posture, in parallel
        case .dashboard, .result, .history: return nil
        }
    }

    @discardableResult
    func startScan(module: ModuleID, scanner customScanner: (any FileScanner)? = nil) -> Task<Void, Never>? {
        guard let scanner = customScanner ?? scanner(for: module) else { return nil }
        update(module) { s in
            s.isScanning = true
            s.progress = 0
            s.status = L("Démarrage…")
            s.result = nil
            s.selection.removeAll()
            s.lastMeasure = nil
        }
        let exclusions = self.exclusions
        let task = Task.detached(priority: .utility) { [weak self] in
            do {
                let result = try await scanner.scanFiltered(exclusions: exclusions, progress: { p, msg in
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
                        // Regenerable items start ticked; personal files, browser
                        // data and the Trash never do.
                        s.selection = SmartCarePlan.defaultSelection(for: module, items: result.items)
                        s.status = result.count == 1
                            ? L("1 élément · \(ByteFormatter.string(result.totalSize))")
                            : L("\(result.count) éléments · \(ByteFormatter.string(result.totalSize))")
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.update(module) { s in
                        s.isScanning = false
                        s.status = L("Annulé")
                    }
                }
            }
        }
        update(module) { $0.currentTask = task }
        return task
    }

    // MARK: — Smart Care

    static let smartCareModules: [ModuleID] = [.cleanup, .developer, .files, .privacy, .security, .performance, .updates]

    /// What Smart Care's own analysis runs: the developer scan skips external
    /// tools (brew, docker, simctl), and every other module uses its usual scanner.
    private func smartCareScanner(for module: ModuleID) -> (any FileScanner)? {
        if let o = scannerOverrides[module] { return o }
        if module == .developer { return DeveloperScanner(includeTools: false) }
        return scanner(for: module)
    }

    var smartCarePlan: SmartCarePlan {
        var results: [ModuleID: ScanResult] = [:]
        var selections: [ModuleID: Set<UUID>] = [:]
        for (m, s) in moduleStates {
            if let r = s.result { results[m] = r }
            selections[m] = s.selection
        }
        return SmartCarePlan(results: results, selections: selections)
    }

    var smartCareProgress: Double {
        let v = Self.smartCareModules.map { state(for: $0).progress }
        return v.reduce(0, +) / Double(max(v.count, 1))
    }

    func startSmartCare() {
        guard smartCare.phase != .scanning, smartCare.phase != .running else { return }
        smartCare.phase = .scanning
        smartCare.scanStarted = Date()
        cameFromSmartCare = false
        refreshDisk()
        let tasks = Self.smartCareModules.compactMap { startScan(module: $0, scanner: smartCareScanner(for: $0)) }
        smartCareTask = Task { @MainActor [weak self] in
            for t in tasks { await t.value }
            guard let self, self.smartCare.phase == .scanning else { return }
            self.smartCare.scanSeconds = Date().timeIntervalSince(self.smartCare.scanStarted ?? Date())
            self.smartCare.phase = .results
            self.smartCare.includeUpdates = false
            self.smartCare.lastScan = Date()
            UserDefaults.standard.set(Date(), forKey: Self.lastScanKey)
            self.refreshDisk()
        }
    }

    func cancelSmartCare() {
        guard smartCare.phase == .scanning else { return }
        smartCare.phase = .home
        smartCareTask?.cancel()
        Self.smartCareModules.forEach { cancelScan(module: $0) }
    }

    /// Back to the home screen to start a fresh analysis.
    func resetSmartCare() {
        guard smartCare.phase == .results else { return }
        smartCare.phase = .home
    }

    static let lastScanKey = "ai.turkeycode.cleanmacpro.smartcare.lastScan"
    var lastSmartCareScan: Date? { UserDefaults.standard.object(forKey: Self.lastScanKey) as? Date }

    /// Card checkbox "Inclure" of the Nettoyage card: ticks / unticks every
    /// regenerable item (caches, logs, temp, developer caches).
    func setCleanupIncluded(_ on: Bool) {
        for m in [ModuleID.cleanup, .developer] {
            guard let r = state(for: m).result else { continue }
            let ids = Set(r.items.filter { $0.kind.isRegenerable }.map(\.id))
            update(m) { s in s.selection = on ? s.selection.union(ids) : s.selection.subtracting(ids) }
        }
    }

    /// "Vider aussi la Corbeille": ticks / unticks the Trash rows.
    func setTrashIncluded(_ on: Bool) {
        guard let r = state(for: .cleanup).result else { return }
        let ids = Set(r.items.filter { $0.kind == .trash }.map(\.id))
        update(.cleanup) { s in s.selection = on ? s.selection.union(ids) : s.selection.subtracting(ids) }
    }

    /// "Lancer": runs exactly `smartCarePlan.runnableItems` (+ Sparkle updates if
    /// ticked), measures the volume's free space before and after, and shows the Result.
    func runSmartCare() {
        guard smartCare.phase == .results else { return }
        let plan = smartCarePlan
        let items = plan.runnableItems
        let installs = smartCare.includeUpdates ? plan.installableUpdates : []
        guard !items.isEmpty || !installs.isEmpty else { return }
        smartCare.phase = .running
        smartCare.runProgress = 0
        smartCare.runStatus = L("Préparation…")

        var groups: [(ModuleID, [ScanItem])] = []
        for m in SmartCarePlan.cleanableModules {
            let ids = Set(state(for: m).result?.items.map(\.id) ?? [])
            let mine = items.filter { ids.contains($0.id) }
            if !mine.isEmpty { groups.append((m, mine)) }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.perform(groups: groups, forcePermanent: false, installs: installs,
                                             source: ModuleID.smartScan.railTitle) { p, status in
                self.smartCare.runProgress = p
                self.smartCare.runStatus = status
            }
            self.lastOutcome = outcome
            self.smartCare.phase = .results
            self.active = .result
        }
    }

    // MARK: — Cleaning

    /// Shared engine for Smart Care and the per-module "Nettoyer" buttons:
    /// measures free space before / after, cleans module by module (policy-aware,
    /// with the admin fallback), installs updates, updates results + history.
    private func perform(groups: [(ModuleID, [ScanItem])], forcePermanent: Bool, installs: [ScanItem],
                         source: String, progress: @escaping @MainActor (Double, String) -> Void) async -> CleanOutcome {
        refreshDisk()
        let before = DiskSpace.snapshot()
        let steps = Double(max(groups.count + (installs.isEmpty ? 0 : 1), 1))
        var done = 0.0
        var rows: [OutcomeRow] = []
        var total = CleanReport.empty

        for (module, items) in groups {
            progress(done / steps, L("Nettoyage : \(module.railTitle)…"))
            let report = await Task.detached(priority: .userInitiated) {
                Cleaner.clean(items: items, forcePermanent: forcePermanent, adminFallback: true)
            }.value
            applyClean(module: module, items: items, report: report)
            rows.append(OutcomeRow(module: module, report: report))
            total = total.merged(with: report)
            done += 1
        }

        var installed = 0, manual = 0, failedInstalls = 0
        if !installs.isEmpty {
            for (i, item) in installs.enumerated() {
                guard let release = item.sparkleRelease else { continue }
                let name = item.url.deletingPathExtension().lastPathComponent
                progress((done + Double(i) / Double(installs.count)) / steps, L("Mise à jour de \(name)…"))
                switch await SparkleInstaller.install(appURL: item.url, release: release, progress: { _ in }) {
                case .installed: installed += 1
                case .manual:    manual += 1
                case .failed:    failedInstalls += 1
                }
            }
            if installed > 0 { startScan(module: .updates) }
            done += 1
        }

        progress(1, L("Mesure de l'espace libéré…"))
        try? await Task.sleep(nanoseconds: 700_000_000)   // let APFS settle before measuring
        let after = DiskSpace.snapshot()
        refreshDisk()
        await ScanCache.shared.invalidate()
        return CleanOutcome(
            source: source,
            measure: SpaceMeasure(before: before, after: after, reportedBytes: total.freedBytes,
                                  trashedBytes: total.trashedBytes),
            report: total, rows: rows,
            updatesInstalled: installed, updatesManual: manual, updatesFailed: failedInstalls)
    }

    /// Per-module "Nettoyer" button. - Parameter permanent: Uninstaller — removes
    /// outright so a removed .app never lingers in the Trash.
    func clean(module: ModuleID, permanent: Bool = false) {
        let state = self.state(for: module)
        guard !state.isCleaning, let result = state.result, !state.selection.isEmpty else { return }
        let toClean = result.items.filter { state.selection.contains($0.id) && $0.kind.isCleanable }
        guard !toClean.isEmpty else { return }

        // Emptying the Trash is the one irreversible step the user must confirm.
        let trashRows = toClean.filter { $0.kind == .trash }
        if !trashRows.isEmpty {
            let alert = NSAlert()
            alert.messageText = L("Vider la Corbeille ?")
            alert.informativeText = L("\(trashRows.count) élément(s) · \(ByteFormatter.string(trashRows.reduce(0) { $0 + $1.size })) seront supprimés définitivement. Cette action est irréversible.")
            alert.addButton(withTitle: L("Vider la Corbeille"))
            alert.addButton(withTitle: L("Annuler"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        update(module) { $0.isCleaning = true; $0.status = L("Nettoyage en cours…") }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.perform(groups: [(module, toClean)], forcePermanent: permanent, installs: [],
                                             source: module.railTitle) { _, status in
                self.update(module) { $0.status = status }
            }
            self.lastOutcome = outcome
            self.update(module) { s in
                s.isCleaning = false
                s.lastReport = outcome.report
                s.lastMeasure = outcome.measure
                s.status = outcome.summaryLine
            }
        }
    }

    /// Empties the whole Trash (menu-bar and Result actions). Confirms first.
    func emptyTrash() {
        let size = FS.directorySize(FS.home.appendingPathComponent(".Trash"))
        let alert = NSAlert()
        alert.messageText = L("Vider la Corbeille ?")
        alert.informativeText = L("\(ByteFormatter.string(size)) seront supprimés définitivement. Cette action est irréversible.")
        alert.addButton(withTitle: L("Vider la Corbeille"))
        alert.addButton(withTitle: L("Annuler"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let before = DiskSpace.snapshot()
            let report = await Task.detached(priority: .userInitiated) { () -> CleanReport? in
                if let r = Cleaner.emptyTrash() { return r }
                // No access to ~/.Trash: let Finder do it (its own permission prompt).
                _ = Shell.run("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty the trash"], timeout: 120)
                return nil
            }.value
            try? await Task.sleep(nanoseconds: 700_000_000)
            let after = DiskSpace.snapshot()
            self.refreshDisk()
            if let report, self.history.record(module: ModuleID.cleanup.rawValue, report: report) != nil {
                try? self.history.save()
            }
            self.update(.cleanup) { s in s.result?.items.removeAll { $0.kind == .trash }; s.selection = s.selection.filter { id in s.result?.items.contains { $0.id == id } == true } }
            let rep = report ?? CleanReport.empty
            self.lastOutcome = CleanOutcome(
                source: L("Corbeille"),
                measure: SpaceMeasure(before: before, after: after, reportedBytes: max(rep.freedBytes, size)),
                report: rep, rows: [], updatesInstalled: 0, updatesManual: 0, updatesFailed: 0)
        }
    }

    // MARK: — Exclusions

    func addExclusion(path: String) { mutateExclusions { $0.addPath(path) } }
    func addExclusion(appID: String) { mutateExclusions { $0.addAppID(appID) } }
    func removeExclusion(path: String) { mutateExclusions { $0.removePath(path) } }
    func removeExclusion(appID: String) { mutateExclusions { $0.removeAppID(appID) } }

    /// "Ne plus proposer": excludes an item (by app id for apps, else by path).
    func exclude(_ item: ScanItem, asApp: Bool = false) {
        if asApp, let id = ExclusionList.bundleID(ofAppAt: item.url) {
            addExclusion(appID: id)
        } else {
            addExclusion(path: item.url.path)
        }
    }

    private func mutateExclusions(_ change: (inout ExclusionList) -> Void) {
        var e = exclusions
        change(&e)
        exclusions = e
        try? e.save()
        // Hide what is already on screen.
        for m in ModuleID.allCases {
            guard let r = moduleStates[m]?.result else { continue }
            let kept = e.apply(to: r)
            if kept.count != r.count {
                update(m) { s in
                    s.result = kept
                    s.selection = s.selection.intersection(Set(kept.items.map(\.id)))
                }
            }
        }
    }

    // MARK: — History

    @discardableResult
    func restore(_ entry: HistoryEntry) -> RestoreOutcome {
        let outcome = CleanHistory.restore(entry)
        if !outcome.restored.isEmpty { Task { await ScanCache.shared.invalidate() } }
        return outcome
    }

    /// Permanent deletions (app-removal prompt): logged without Trash records.
    func recordPermanentRemoval(_ report: CleanReport) {
        if history.recordPermanent(module: ModuleID.uninstaller.rawValue, report: report) != nil {
            try? history.save()
        }
    }

    func removeHistoryEntry(_ entry: HistoryEntry) {
        history.remove(id: entry.id)
        try? history.save()
    }

    func clearHistory() {
        history = CleanHistory()
        try? history.save()
    }

    // MARK: — Schedule

    func setSchedule(_ s: ScanSchedule) {
        schedule = s
        try? ScheduledScanAgent.saveSchedule(s)
        ScheduleInstaller.apply(s)
    }

    func cancelScan(module: ModuleID) {
        moduleStates[module]?.currentTask?.cancel()
        update(module) { s in
            s.isScanning = false
            s.status = L("Annulé")
        }
    }

    /// Removes successfully-cleaned items from the module result, records the
    /// history entry (restorable only for what went to the Trash).
    private func applyClean(module: ModuleID, items: [ScanItem], report: CleanReport) {
        if history.record(module: module.rawValue, report: report) != nil {
            try? history.save()
        }
        let failed = Set(report.failedItems)
        let gone = Set(items.filter { !failed.contains($0.url) }.map(\.id))
        update(module) { s in
            s.lastReport = report
            s.result?.items.removeAll { gone.contains($0.id) }
            s.selection.subtract(gone)
        }
    }
}

/// Smart Care screen state.
enum SmartCarePhase { case home, scanning, results, running }

struct SmartCareState {
    var phase: SmartCarePhase = .home
    var scanStarted: Date?
    var scanSeconds: Double = 0
    var lastScan: Date?
    /// "Mettre à jour" tick of the Applications card (off by default).
    var includeUpdates = false
    var runProgress: Double = 0
    var runStatus: String = ""
}

/// One line of the Result breakdown.
struct OutcomeRow: Identifiable {
    let id = UUID()
    let module: ModuleID
    let report: CleanReport
}

/// What a cleanup really did.
struct CleanOutcome {
    var source: String
    var measure: SpaceMeasure
    var report: CleanReport
    var rows: [OutcomeRow]
    var updatesInstalled: Int
    var updatesManual: Int
    var updatesFailed: Int
    var date = Date()

    var summaryLine: String {
        var s = L("Libéré \(ByteFormatter.string(measure.freedBytes)) sur le disque")
        if report.trashedCount > 0 { s += " · " + L("\(ByteFormatter.string(report.trashedBytes)) dans la Corbeille") }
        if !report.failedItems.isEmpty { s += " · " + L("\(report.failedItems.count) échec(s)") }
        return s
    }
}

struct ModuleState {
    var isScanning: Bool = false
    var progress: Double = 0
    var status: String = L("Prêt")
    var result: ScanResult? = nil
    var selection: Set<UUID> = []
    var lastReport: CleanReport? = nil
    var lastMeasure: SpaceMeasure? = nil
    var isCleaning: Bool = false
    var currentTask: Task<Void, Never>? = nil
    var sortKey: SortKey = .size
    var sortDescending: Bool = true
}

enum SortKey: String, CaseIterable, Identifiable {
    case size, name, modified
    var id: String { rawValue }
    var label: String {
        switch self {
        case .size: return L("Taille")
        case .name: return L("Nom")
        case .modified: return L("Date")
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
