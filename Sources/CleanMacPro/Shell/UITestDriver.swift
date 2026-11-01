import SwiftUI
import AppKit
import CleanCore

/// Built-in UI test mode (`--ui-test [--ui-test-out=<dir>]`), driven by CI on a
/// macOS runner with a graphical session. It skips the onboarding, walks every
/// screen (all `ModuleID` cases, the settings window, the menu-bar popover),
/// writes one PNG per screen plus `report.json`, then quits.
///
/// Safety: it only ever cleans a throw-away fixture tree created inside the
/// output directory (every scanner is replaced by a fixture), never runs
/// maintenance commands, never asks for admin rights and never touches the
/// user's own files. It also drives the Smart Care flow end to end ("Lancer")
/// and checks the outcome on disk.
@MainActor
final class UITestDriver {
    static let argument = "--ui-test"
    static let shared = UITestDriver()
    static var isEnabled: Bool { CommandLine.arguments.contains(argument) }

    private struct ScreenReport: Codable {
        var id: String
        var title: String
        var renderOK = false
        var views = 0
        var accessibilityNodes = 0
        var edgePixels = 0
        var png: String? = nil
        var error: String? = nil
    }

    private struct Report: Codable {
        var ok = false
        var startedAt = ISO8601DateFormatter().string(from: Date())
        var durationSeconds = 0.0
        var mainWindowFound = false
        var mainWindowSize = ""
        var statusItemPresent = false
        var statusItemHasImage = false
        var statusItemVisible = false
        var cleanupFixtureItems = 0
        var spaceLensFixtureItems = 0
        var screens: [ScreenReport] = []
        var notes: [String] = []
        var errors: [String] = []
    }

    private var report = Report()
    private var outDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cleanmac-ui")
    private var started = Date()
    private var previousDigest: Int?

    private var appState: AppState { AppState.shared }

    // MARK: Entry

    func start() {
        let args = CommandLine.arguments
        // Single token on purpose: a bare path argument would make AppKit try to
        // "open" it as a document and suppress the main window.
        if let a = args.first(where: { $0.hasPrefix("--ui-test-out=") }) {
            outDir = URL(fileURLWithPath: String(a.dropFirst("--ui-test-out=".count)))
        }
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        started = Date()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            await self.run()
            self.finish()
        }
        // Watchdog: a hung screen must fail the run, not stall the job.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420 * 1_000_000_000)
            self.report.errors.append("watchdog: timeout after 420 s")
            self.finish()
        }
    }

    private func log(_ m: String) { FileHandle.standardError.write(Data(("[ui-test] " + m + "\n").utf8)) }

    private func fail(_ message: String) { report.errors.append(message) }

    private func finish() {
        log("finish")
        report.durationSeconds = Date().timeIntervalSince(started)
        report.ok = report.errors.isEmpty
        writeReport()
        AppLifecycle.shared.reallyQuit = true
        // Exit code mirrors the verdict so the workflow can rely on it too.
        exit(report.ok ? 0 : 1)
    }

    private func writeReport() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(report) {
            try? data.write(to: outDir.appendingPathComponent("report.json"))
        }
    }

    // MARK: Run

    private func run() async {
        // Fixture trees (inside the output dir). Everything cleaned below lives here.
        let fixture = outDir.appendingPathComponent("fixture", isDirectory: true)
        let lensRoot = fixture.appendingPathComponent("Lens", isDirectory: true)
        let fx = makeFixture(lensRoot: lensRoot)
        fixtureRoot = fx
        appState.scannerOverrides = fx.scanners(lensRoot: lensRoot)
        appState.showOnboarding = false   // not persisted
        // Dark first, whatever the runner's macOS appearance (not persisted); the
        // light pass at the end switches to "Clair".
        appState.appearance = .dark
        // Deterministic permission states (no system probing, no dialogs) so the banner is captured.
        PermissionCenter.shared.forced = [.fullDiskAccess: .denied, .notifications: .notDetermined, .automation: .granted]

        // 1. Main window.
        guard let main = await waitForMainWindow() else {
            fail("main window did not appear within 40 s")
            return
        }
        report.mainWindowFound = true
        report.mainWindowSize = "\(Int(main.frame.width))x\(Int(main.frame.height))"
        NSApp.activate(ignoringOtherApps: true)
        main.makeKeyAndOrderFront(nil)

        // 2. Menu-bar icon.
        if let item = AppDelegate.current?.statusItem, let button = item.button {
            report.statusItemPresent = true
            report.statusItemHasImage = button.image != nil
            report.statusItemVisible = item.isVisible && (button.window?.isVisible ?? false)
        }
        if !report.statusItemPresent { fail("menu-bar status item missing") }
        if !report.statusItemHasImage { fail("menu-bar status item has no image") }
        if !report.statusItemVisible { fail("menu-bar status item not visible") }

        // 3. Every module screen (idle state).
        for module in ModuleID.allCases {
            appState.active = module
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            record(window: main, id: module.rawValue, title: module.title,
                   file: "screen-\(module.rawValue).png", distinct: module != .dashboard)
        }

        // 4. Space Lens on its fixture.
        appState.active = .spaceLens
        appState.startScan(module: .spaceLens)
        if await waitForScan(.spaceLens) {
            let n = appState.state(for: .spaceLens).result?.items.count ?? 0
            report.spaceLensFixtureItems = n
            if n == 0 { fail("Space Lens scan on fixture returned no items") }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            record(window: main, id: "spaceLens-scanned", title: "Space Lens (scan fixture)",
                   file: "screen-spaceLens-scanned.png", distinct: true)
        }

        // 4b. Transient Smart Care phases (too quick on fixtures to be seen otherwise).
        await captureTransientPhases(main: main, prefix: "screen")

        // 5. Smart Care, end to end on the fixtures.
        await smartCareFlow(main: main, fx: fx)

        log("settings")
        // 5. Settings window (scene first, hosted fallback if the scene does not open).
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        var settings = NSApp.windows.first(where: {
            $0 !== main && $0 !== fallbackWindow && $0.isVisible && $0.styleMask.contains(.titled) && $0.contentView != nil
        })
        if settings == nil {
            report.notes.append("settings scene window did not open; hosting SettingsView in a window")
            let host = NSHostingView(rootView: SettingsView()
                .environmentObject(appState)
                .themed(appState))
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.title = L("Réglages")
            w.contentView = host
            w.center()
            w.makeKeyAndOrderFront(nil)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            settings = w
        }
        if let settings {
            record(window: settings, id: "settings", title: "Réglages",
                   file: "screen-settings.png", distinct: false)
            settings.close()
        }

        // 5b. Permissions: Settings tab + onboarding step (hosted windows, forced states).
        for (id, file, size, root) in [
            ("settings-permissions", "screen-settings-permissions.png", NSSize(width: 560, height: 420),
             AnyView(SettingsView(initialTab: .permissions).environmentObject(appState).themed(appState))),
            ("onboarding-permissions", "screen-onboarding-permissions.png", NSSize(width: 1000, height: 800),
             AnyView(OnboardingOverlay(initialStep: 2).environmentObject(appState).themed(appState))),
        ] {
            let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: root.frame(width: size.width, height: size.height))
            w.center()
            w.makeKeyAndOrderFront(nil)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            record(window: w, id: id, title: id, file: file, distinct: false)
            w.close()
        }

        log("removal prompt")
        // 5b. "App removed" prompt on a throw-away fixture: every button gets a real effect.
        await runRemovalPromptChecks()

        log("popover")
        // 6. Menu-bar popover.
        if let delegate = AppDelegate.current, let item = delegate.statusItem,
           let button = item.button, let pop = delegate.popover {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let w = pop.contentViewController?.view.window {
                record(window: w, id: "menubar-popover", title: "Panneau barre de menus",
                       file: "screen-menubar-popover.png", distinct: false)
            } else {
                fail("menu-bar popover has no window")
            }
            pop.performClose(nil)
        }
        log("light")
        await lightAppearancePass(main: main)

        log("done")
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: Light appearance

    /// Réglages › Apparence › Clair: every module, Settings and the menu-bar popover
    /// are captured again, and their pixels must really be light (not a dark
    /// screen with a light title bar). The dark captures are checked the other way.
    private func lightAppearancePass(main: NSWindow) async {
        appState.navigate(to: .smartScan)
        try? await Task.sleep(nanoseconds: 800_000_000)
        if let l = contentLuminance(main) { check(l < 0.35, "dark appearance renders dark (median \(fmt(l)))") }

        appState.appearance = .light
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        check(NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua, "NSApp switched to light")
        for module in ModuleID.allCases where module != .result {
            appState.active = module
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            record(window: main, id: "light-\(module.rawValue)", title: module.title + " (clair)",
                   file: "light-\(module.rawValue).png", distinct: false)
            // Space Lens draws a full-width colored treemap of the fixture: not a canvas test.
            if module != .spaceLens, let l = contentLuminance(main) {
                check(l > 0.7, "light \(module.rawValue) renders light (median \(fmt(l)))")
            }
        }

        await captureTransientPhases(main: main, prefix: "light")

        let size = NSSize(width: 560, height: 420)
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: SettingsView().environmentObject(appState).themed(appState)
            .frame(width: size.width, height: size.height))
        w.center()
        w.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        record(window: w, id: "light-settings", title: "Réglages (clair)", file: "light-settings.png", distinct: false)
        w.close()

        if let delegate = AppDelegate.current, let item = delegate.statusItem,
           let button = item.button, let pop = delegate.popover {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if let pw = pop.contentViewController?.view.window {
                record(window: pw, id: "light-menubar-popover", title: "Barre de menus (clair)",
                       file: "light-menubar-popover.png", distinct: false)
                if let l = contentLuminance(pw) { check(l > 0.7, "light menu-bar popover renders light (median \(fmt(l)))") }
            }
            pop.performClose(nil)
        }

        appState.appearance = .system
        try? await Task.sleep(nanoseconds: 500_000_000)
        appState.navigate(to: .smartScan)
    }

    /// Smart Care "scanning" and "running" screens, forced for a capture.
    private func captureTransientPhases(main: NSWindow, prefix: String) async {
        let saved = appState.smartCare
        appState.navigate(to: .smartScan)
        appState.smartCare.phase = .scanning
        try? await Task.sleep(nanoseconds: 900_000_000)
        record(window: main, id: "\(prefix)-smartcare-scanning", title: "Smart Care (analyse en cours)",
               file: "\(prefix)-smartcare-scanning.png", distinct: false)
        appState.smartCare.phase = .running
        appState.smartCare.runProgress = 0.4
        appState.smartCare.runStatus = L("Nettoyage")
        try? await Task.sleep(nanoseconds: 900_000_000)
        record(window: main, id: "\(prefix)-smartcare-running", title: "Smart Care (nettoyage en cours)",
               file: "\(prefix)-smartcare-running.png", distinct: false)
        appState.smartCare = saved
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    /// Median luminance of a sparse grid over the content area (sidebar skipped
    /// for the main window).
    private func contentLuminance(_ window: NSWindow) -> Double? {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = Double(rep.pixelsWide) / max(1, Double(view.bounds.width))   // Retina: 2 px per pt
        let skip = Int((window.frame.width >= 900 ? 240 : 0) * scale)
        var values: [Double] = []
        var y = Int(40 * scale)
        while y < rep.pixelsHigh - 10 {
            var x = skip + 10
            while x < rep.pixelsWide - 10 {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    values.append(0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent)
                }
                x += 23
            }
            y += 23
        }
        guard !values.isEmpty else { return nil }
        return values.sorted()[values.count / 2]
    }

    // MARK: Removal prompt

    private func runRemovalPromptChecks() async {
        let fm = FileManager.default
        let dir = outDir.appendingPathComponent("removal-fixture")
        try? fm.removeItem(at: dir)
        var items: [ScanItem] = []
        for (name, kb) in [("Application Support/Vivaldi", 1500), ("Caches/com.vivaldi.Vivaldi", 286),
                           ("Preferences/com.vivaldi.Vivaldi.plist", 12), ("Saved Application State/com.vivaldi.Vivaldi.savedState", 3)] {
            let u = dir.appendingPathComponent(name)
            try? fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data(repeating: 7, count: kb * 1024).write(to: u)
            items.append(ScanItem(url: u, size: Int64(kb * 1024), kind: .appResidue, group: "Vivaldi"))
        }
        func event() -> AppRemovalEvent {
            AppRemovalEvent(appName: "Vivaldi", bundleID: "com.vivaldi.ui-test", appPath: "/nonexistent/Vivaldi.app", items: items)
        }
        guard let (panel, model) = AppRemovalCoordinator.shared.presentForTesting(event()) else {
            fail("removal prompt did not open"); return
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        record(window: panel, id: "removal-prompt", title: "Invite app supprimée",
               file: "screen-removal-prompt.png", distinct: false)
        model.expanded = false
        try? await Task.sleep(nanoseconds: 800_000_000)
        record(window: panel, id: "removal-prompt-collapsed", title: "Invite app supprimée (repliée)",
               file: "screen-removal-prompt-collapsed.png", distinct: false)
        model.expanded = true

        // Ignorer: closes, deletes nothing.
        model.ignoreOnce()
        if items.contains(where: { !fm.fileExists(atPath: $0.url.path) }) { fail("removal prompt: Ignorer deleted files") }
        if panel.isVisible { fail("removal prompt: Ignorer did not close the panel") }

        // Toujours ignorer: adds the app id to the exclusions, deletes nothing.
        if let (p2, m2) = AppRemovalCoordinator.shared.presentForTesting(event()) {
            m2.alwaysIgnore()
            if !appState.exclusions.appIDs.contains("com.vivaldi.ui-test") { fail("removal prompt: Toujours ignorer did not exclude the app") }
            appState.removeExclusion(appID: "com.vivaldi.ui-test")
            if p2.isVisible { fail("removal prompt: Toujours ignorer did not close the panel") }
            if items.contains(where: { !fm.fileExists(atPath: $0.url.path) }) { fail("removal prompt: Toujours ignorer deleted files") }
        } else { fail("removal prompt (2) did not open") }

        // Supprimer: really deletes the fixture and logs history.
        let before = appState.history.entries.count
        if let (p3, m3) = AppRemovalCoordinator.shared.presentForTesting(event()) {
            m3.deleteAll()
            try? await Task.sleep(nanoseconds: 700_000_000)
            record(window: p3, id: "removal-prompt-done", title: "Invite app supprimée (terminé)",
                   file: "screen-removal-prompt-done.png", distinct: false)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if items.contains(where: { fm.fileExists(atPath: $0.url.path) }) { fail("removal prompt: Supprimer left files behind") }
            if appState.history.entries.count != before + 1 { fail("removal prompt: deletion not recorded in history") }
            if p3.isVisible { fail("removal prompt: panel still visible after deletion") }
            report.notes.append("removal prompt: Ignorer / Toujours ignorer / Supprimer verified on fixture")
        } else { fail("removal prompt (3) did not open") }
        try? fm.removeItem(at: dir)
    }

    // MARK: Helpers

    private func windowDump() -> String {
        NSApp.windows.map { w in
            "[\(type(of: w)) title=\"\(w.title)\" visible=\(w.isVisible) frame=\(Int(w.frame.width))x\(Int(w.frame.height)) mask=\(w.styleMask.rawValue) content=\(Int(w.contentView?.bounds.width ?? -1))]"
        }.joined(separator: " ") + " policy=\(NSApp.activationPolicy().rawValue) active=\(NSApp.isActive)"
    }

    private func waitForMainWindow() async -> NSWindow? {
        for i in 0..<80 {
            if let w = NSApp.windows.first(where: { ($0.contentView?.bounds.width ?? 0) >= 900 && $0.styleMask.contains(.titled) }) {
                if !w.isVisible { w.makeKeyAndOrderFront(nil) }
                if w.isVisible { return w }
            }
            if i == 6 || i == 20 { WindowOpener.shared.open?() }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        report.notes.append("scene window missing; windows: " + windowDump()
                            + " opener=\(WindowOpener.shared.open != nil)")
        // Fallback: host the very same RootView in our own window.
        let host = NSHostingView(rootView: RootView()
            .environmentObject(appState)
            .environmentObject(appState.hostStats)
            .environmentObject(appState.background)
            .themed(appState)
            .frame(width: 1100, height: 720))
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.contentView = host
        w.center()
        w.makeKeyAndOrderFront(nil)
        fallbackWindow = w
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return w.isVisible ? w : nil
    }
    private var fallbackWindow: NSWindow?

    private func waitForScan(_ module: ModuleID) async -> Bool {
        for _ in 0..<240 {
            let s = appState.state(for: module)
            if !s.isScanning && s.result != nil { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        fail("\(module.rawValue) scan did not finish within 120 s")
        return false
    }

    private var fixtureRoot: Fixture?

    private func check(_ ok: Bool, _ what: String) {
        if ok { report.notes.append("ok: " + what) } else { fail("check failed: " + what) }
    }

    private func waitFor(_ what: String, seconds: Int = 120, _ cond: () -> Bool) async -> Bool {
        for _ in 0..<(seconds * 4) {
            if cond() { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        fail("timeout waiting for \(what)")
        return false
    }

    /// Smart Care: analyse → results cards → review screens → explicit selection →
    /// "Lancer" → real deletion checked on disk → Result → History → restore.
    private func smartCareFlow(main: NSWindow, fx: Fixture) async {
        let fm = FileManager.default
        appState.navigate(to: .smartScan)
        appState.startSmartCare()
        try? await Task.sleep(nanoseconds: 600_000_000)
        record(window: main, id: "smartcare-scanning", title: "Smart Care (analyse)",
               file: "screen-smartcare-scanning.png", distinct: false)
        guard await waitFor("Smart Care analysis", { appState.smartCare.phase == .results }) else { return }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        record(window: main, id: "smartcare-results", title: "Smart Care (résultats)",
               file: "screen-smartcare-results.png", distinct: false)

        // Default selection: only regenerable items; personal files / browser data / Trash untouched.
        let plan = appState.smartCarePlan
        check(plan.regenerableBytes > 0, "analysis found regenerable data")
        check(!plan.runnableItems.isEmpty && plan.runnableItems.allSatisfy { $0.kind.isRegenerable },
              "default run contains only caches / logs / temp files")
        check(plan.selectedClutter.isEmpty && plan.selectedPrivacy.isEmpty && !plan.trashSelected,
              "personal files, browser data and the Trash are not selected by default")
        check(plan.clutterBytes > 0 && plan.privacyBytes > 0 && plan.trashBytes > 0 && !plan.updates.isEmpty,
              "every card has data")

        // Review screens opened from the cards.
        for (module, id) in [(ModuleID.cleanup, "review-cleanup"), (.developer, "review-developer"),
                             (.files, "review-files"), (.privacy, "review-privacy"),
                             (.security, "review-security"), (.updates, "review-updates"),
                             (.performance, "review-performance")] {
            appState.review(module)
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            record(window: main, id: id, title: "Revue \(module.rawValue)", file: "screen-\(id).png", distinct: false)
        }

        // Explicit review: the user picks one duplicate and ticks the Trash.
        appState.backToSmartCare()
        let dup = appState.state(for: .files).result?.items.first { $0.kind == .duplicate }
        check(dup != nil, "files fixture contains a duplicate")
        if let dup { appState.update(.files) { $0.selection.insert(dup.id) } }
        appState.setTrashIncluded(true)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        record(window: main, id: "smartcare-results-selected", title: "Smart Care (sélection)",
               file: "screen-smartcare-results-selected.png", distinct: false)

        let run = appState.smartCarePlan
        let cacheURLs = run.regenerableItems.map(\.url)
        check(run.runnableItems.contains { $0.kind == .duplicate } && run.runnableItems.contains { $0.kind == .trash },
              "explicit selection is part of the run")
        check(run.runnableItems.allSatisfy { fx.owns($0.url) }, "everything about to be cleaned is inside the fixture")
        let keeperURL = appState.state(for: .files).result?.items.first { $0.kind == .keeper }?.url
        let largeURL = appState.state(for: .files).result?.items.first { $0.kind == .largeFile }?.url
        let totalBefore = appState.history.entries.count

        appState.runSmartCare()
        try? await Task.sleep(nanoseconds: 300_000_000)
        record(window: main, id: "smartcare-running", title: "Smart Care (nettoyage)",
               file: "screen-smartcare-running.png", distinct: false)
        guard await waitFor("Smart Care run", { appState.lastOutcome != nil && appState.smartCare.phase == .results }) else { return }
        try? await Task.sleep(nanoseconds: 1_800_000_000)

        // Result on disk.
        check(cacheURLs.allSatisfy { !fm.fileExists(atPath: $0.path) }, "caches, logs and temp files were deleted for good")
        check(dup.map { !fm.fileExists(atPath: $0.url.path) } ?? false, "the chosen duplicate left its folder")
        check(keeperURL.map { fm.fileExists(atPath: $0.path) } ?? false, "the kept original is untouched")
        check(largeURL.map { fm.fileExists(atPath: $0.path) } ?? false, "unselected personal files are untouched")
        check(fx.trashItems.allSatisfy { !fm.fileExists(atPath: $0.path) }, "the ticked Trash was emptied")
        if let o = appState.lastOutcome {
            check(o.report.failedItems.isEmpty, "no failed item")
            check(o.measure.before != nil && o.measure.after != nil, "free space measured before and after")
            check(o.report.permanentCount > 0 && o.report.trashedCount >= 1, "report splits permanent deletions and Trash moves")
            check(appState.history.entries.count > totalBefore, "history entries were recorded")
        }
        check(appState.active == .result, "Result screen shown after the run")
        record(window: main, id: "result-after-run", title: "Résultat (nettoyage réel)",
               file: "screen-result-after-run.png", distinct: false)

        // History: the Trash move is restorable, the permanent deletions are not.
        appState.navigate(to: .history)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        record(window: main, id: "history-after-run", title: "Historique", file: "screen-history-after-run.png", distinct: false)
        let restorable = appState.history.entries.first { $0.canRestore }
        check(restorable != nil, "a restorable history entry exists")
        check(appState.history.entries.contains { !$0.canRestore && $0.permanentCount > 0 },
              "permanent deletions are recorded without a restore button")
        if let e = restorable, let dup {
            _ = appState.restore(e)
            check(fm.fileExists(atPath: dup.url.path), "Restaurer brings the duplicate back")
        }

        // The Smart Care screen after the run: remaining cards, nothing left to run.
        appState.navigate(to: .smartScan)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        record(window: main, id: "smartcare-after-run", title: "Smart Care (après nettoyage)",
               file: "screen-smartcare-after-run.png", distinct: false)
        check(!appState.smartCarePlan.hasWork, "nothing left to run")
    }

    private func record(window: NSWindow, id: String, title: String, file: String, distinct: Bool) {
        var s = ScreenReport(id: id, title: title)
        guard let view = window.contentView else {
            s.error = "window has no content view"
            fail("\(id): \(s.error!)")
            report.screens.append(s)
            return
        }
        s.views = countViews(view)
        s.accessibilityNodes = countAX(view, depth: 0)
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            s.error = "cannot create bitmap for window"
            fail("\(id): \(s.error!)")
            report.screens.append(s)
            return
        }
        view.cacheDisplay(in: bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: outDir.appendingPathComponent(file))
            s.png = file
        }
        // Content area: skip the 232 pt sidebar for the main window.
        let isMain = window.frame.width >= 900
        s.edgePixels = edgePixels(rep, skipLeft: isMain ? 232 : 0)
        let digest = pixelDigest(rep)

        var problems: [String] = []
        if s.views == 0 { problems.append("no views") }
        if isMain {
            let probe = LayoutProbe.shared
            if abs(probe.railMinX) > 0.5 { problems.append("sidebar shifted by \(Int(probe.railMinX)) pt (content overflow)") }
            if probe.contentWidth > probe.paneWidth + 0.5 {
                problems.append("screen wider than its pane (\(Int(probe.contentWidth)) > \(Int(probe.paneWidth)) pt)")
            }
        }
        if s.edgePixels < 10 { problems.append("screen looks empty (edge pixels \(s.edgePixels))") }
        if distinct, let prev = previousDigest, prev == digest { problems.append("identical to previous screen") }
        if isMain { previousDigest = digest }
        s.renderOK = problems.isEmpty
        if !problems.isEmpty {
            s.error = problems.joined(separator: "; ")
            fail("\(id): \(s.error!)")
        }
        report.screens.append(s)
        writeReport()
    }

    private func countViews(_ v: NSView) -> Int { 1 + v.subviews.reduce(0) { $0 + countViews($1) } }

    private func countAX(_ element: Any, depth: Int) -> Int {
        guard depth < 14 else { return 0 }
        var children: [Any] = []
        if let v = element as? NSView { children = v.accessibilityChildren() ?? [] }
        else if let e = element as? NSAccessibilityElement { children = e.accessibilityChildren() ?? [] }
        return 1 + children.prefix(400).reduce(0) { $0 + countAX($1, depth: depth + 1) }
    }

    /// Counts sampled pixels that differ clearly from a neighbour 6 px to the
    /// right: smooth gradients give ~0, text / glyphs / cards give many.
    private func edgePixels(_ rep: NSBitmapImageRep, skipLeft: Int) -> Int {
        let w = rep.pixelsWide, h = rep.pixelsHigh
        let scale = max(1, w / max(1, Int(rep.size.width)))
        var count = 0
        var y = 8
        while y < h - 8 {
            var x = skipLeft * scale + 8
            while x < w - 14 {
                if let a = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   let b = rep.colorAt(x: x + 6, y: y)?.usingColorSpace(.deviceRGB) {
                    let d = abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent)
                          + abs(a.blueComponent - b.blueComponent)
                    if d > 0.25 { count += 1 }
                }
                x += 7
            }
            y += 7
        }
        return count
    }

    private func pixelDigest(_ rep: NSBitmapImageRep) -> Int {
        var hasher = Hasher()
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var y = 5
        while y < h {
            var x = 5
            while x < w {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                    hasher.combine(Int(c.redComponent * 31))
                    hasher.combine(Int(c.greenComponent * 31))
                    hasher.combine(Int(c.blueComponent * 31))
                }
                x += 37
            }
            y += 37
        }
        return hasher.finalize()
    }
}

// MARK: — Fixtures

/// A scanner that reports what currently exists in the fixture tree, after a
/// short pause so progress animations are visible in the screenshots.
private struct FixtureScanner: FileScanner {
    let module: ModuleID
    let build: @Sendable () -> [ScanItem]
    func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.4, "…")
        try await Task.sleep(nanoseconds: 700_000_000)
        progress(1, "Done")
        return ScanResult(module: module, items: build())
    }
}

private func fixtureDirItem(_ url: URL, kind: ItemKind, group: String, title: String? = nil) -> ScanItem? {
    var size: Int64 = 0, count = 0
    for f in FS.enumerate(url) { size += FS.size(of: f); count += 1 }
    guard size > 0 else { return nil }
    return ScanItem(url: url, size: size, modified: FS.modified(of: url), kind: kind, group: group, title: title,
                    detail: count == 1 ? L("1 fichier") : L("\(Int(count)) fichiers"), fileCount: count)
}

private func fixtureChildren(_ dir: URL) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

struct Fixture {
    let root: URL
    var trashItems: [URL]

    func owns(_ url: URL) -> Bool { url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") }

    func scanners(lensRoot: URL) -> [ModuleID: any FileScanner] {
        let root = self.root
        let caches = root.appendingPathComponent("Caches")
        let logs = root.appendingPathComponent("Logs")
        let temp = root.appendingPathComponent("Temp")
        let trash = root.appendingPathComponent("Trash")
        let browsers = root.appendingPathComponent("Browsers")
        let downloads = root.appendingPathComponent("Downloads")
        let devHome = root.appendingPathComponent("DevHome")
        let release = SparkleRelease(shortVersion: "2.0.2", build: "202",
                                     downloadURL: URL(string: "https://example.invalid/app.zip"))
        return [
            .cleanup: FixtureScanner(module: .cleanup) {
                var items: [ScanItem] = []
                for d in fixtureChildren(caches) {
                    if let i = fixtureDirItem(d, kind: .cache, group: CleanupScanner.Group.appCaches) { items.append(i) }
                }
                for d in fixtureChildren(temp) {
                    if let i = fixtureDirItem(d, kind: .tempFile, group: CleanupScanner.Group.temp) { items.append(i) }
                }
                for d in fixtureChildren(logs) {
                    if let i = fixtureDirItem(d, kind: .log, group: CleanupScanner.Group.logs) { items.append(i) }
                }
                for f in fixtureChildren(trash) {
                    items.append(ScanItem(url: f, size: FS.size(of: f), modified: FS.modified(of: f), kind: .trash,
                                          group: CleanupScanner.Group.trash))
                }
                return items
            },
            .developer: DeveloperScanner(home: devHome, projectRoots: [], includeTools: false),
            .files: FilesScanner(large: LargeFilesScanner(roots: [downloads], minSize: 600 * 1024),
                                 duplicates: DuplicatesScanner(roots: [downloads], minSize: 100 * 1024)),
            .privacy: FixtureScanner(module: .privacy) {
                fixtureChildren(browsers).compactMap {
                    fixtureDirItem($0, kind: .privacyData, group: $0.lastPathComponent, title: $0.lastPathComponent)
                }
            },
            .security: FixtureScanner(module: .security) {
                func f(_ t: String, _ d: String, _ sev: Severity, _ g: String = L("Système")) -> ScanItem {
                    ScanItem(url: URL(fileURLWithPath: "/System/\(t)"), size: 0, kind: .securityFinding,
                             group: g, title: t, detail: d, severity: sev)
                }
                return [
                    f("FileVault", L("Activé — disque chiffré"), .good),
                    f("Gatekeeper", L("Activé"), .good),
                    f("SIP", L("Activé"), .good),
                    f(L("Pare-feu"), L("Désactivé"), .warn),
                    f("XProtect", L("À jour"), .good),
                    f(L("Aucune menace connue détectée"), "", .good, L("Menaces")),
                ]
            },
            .performance: FixtureScanner(module: .performance) {
                ["Spotify", "Dropbox", "Zoom"].map {
                    ScanItem(url: URL(fileURLWithPath: "/LoginItems/\($0)"), size: 0, kind: .loginItem,
                             group: L("Éléments de connexion"), title: $0,
                             detail: L("S'ouvre à chaque démarrage — clique pour désactiver"),
                             severity: .info, command: "true")
                }
            },
            .updates: FixtureScanner(module: .updates) {
                var out: [ScanItem] = []
                for n in ["BuhoLaunchpad", "Rectangle", "iTerm"] {
                    out.append(ScanItem(url: URL(fileURLWithPath: "/Applications/\(n).app"), size: 0, kind: .updateAvailable,
                                        group: "Apps · Direct (Sparkle)", title: "\(n) — v2.0.0 → v2.0.2",
                                        detail: "Sparkle", severity: .warn, command: "true", sparkleRelease: release))
                }
                for n in ["Outlook", "Numbers"] {
                    out.append(ScanItem(url: URL(fileURLWithPath: "/Applications/\(n).app"), size: 0, kind: .updateAvailable,
                                        group: "Apps · App Store", title: "\(n) — v1 → v2", severity: .warn))
                }
                out.append(ScanItem(url: URL(fileURLWithPath: "/opt/homebrew/ada-url"), size: 0, kind: .updateAvailable,
                                    group: "Homebrew · formulae", title: "ada-url", severity: .warn, command: "true"))
                return out
            },
            .spaceLens: SpaceLensScanner(roots: [lensRoot]),
        ]
    }
}

extension UITestDriver {
    fileprivate func makeFixture(lensRoot: URL) -> Fixture {
        let fm = FileManager.default
        let root = lensRoot.deletingLastPathComponent()
        try? fm.removeItem(at: root)
        func write(_ rel: String, kb: Int, byte: UInt8 = 0x41, age: Double? = nil) {
            let url = root.appendingPathComponent(rel)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data(repeating: byte, count: kb * 1024).write(to: url)
            if let age { try? fm.setAttributes([.modificationDate: Date().addingTimeInterval(-age * 86_400)], ofItemAtPath: url.path) }
        }
        // App caches (bundle ids of apps that exist on a stock macOS runner, plus one that does not).
        let apps: [(String, Int, Int)] = [
            ("com.apple.Safari", 9, 220), ("com.google.Chrome", 7, 180), ("com.microsoft.VSCode", 5, 160),
            ("com.apple.dt.Xcode", 6, 120), ("com.apple.Notes", 4, 90), ("org.mozilla.firefox", 8, 140),
            ("com.spotify.client", 5, 100),
        ]
        for (id, n, kb) in apps { for i in 1...n { write("Caches/\(id)/data-\(i).cache", kb: kb) } }
        for i in 1...6 { write("Temp/com.example.tmp/part-\(i).tmp", kb: 110) }
        for i in 1...4 { write("Logs/DiagnosticReports/crash-\(i).ips", kb: 60) }
        var trash: [URL] = []
        for i in 1...2 {
            write("Trash/old-download-\(i).dmg", kb: 300)
            trash.append(root.appendingPathComponent("Trash/old-download-\(i).dmg"))
        }
        // Personal files (must never be touched unless chosen).
        write("Downloads/Installer.dmg", kb: 900, byte: 0x51)
        write("Downloads/Archive.zip", kb: 700, byte: 0x52)
        write("Downloads/report.pdf", kb: 300, byte: 0x53)
        write("Downloads/report copy.pdf", kb: 300, byte: 0x53)
        write("Downloads/old-notes.txt", kb: 4, byte: 0x54, age: 400)
        // Browser data, developer caches, Space Lens.
        for (b, n) in [("Firefox", 6), ("Chrome", 4), ("Safari", 2)] { for i in 1...n { write("Browsers/\(b)/cache-\(i).bin", kb: 200) } }
        for i in 1...5 { write("DevHome/Library/Developer/Xcode/DerivedData/MyApp-abc/Build/o-\(i).o", kb: 400) }
        for i in 1...4 { write("DevHome/.npm/_cacache/c-\(i).bin", kb: 250) }
        for (dir, kb) in [("Videos", 900), ("Photos", 600), ("Docs", 250), ("Archive", 120)] {
            for i in 1...3 { write("Lens/\(dir)/file-\(i).dat", kb: kb) }
        }
        return Fixture(root: root, trashItems: trash)
    }
}
