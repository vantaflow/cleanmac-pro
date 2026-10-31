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
                .environment(\.theme, appState.theme))
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
        log("done")
        try? await Task.sleep(nanoseconds: 300_000_000)
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
            .environment(\.theme, appState.theme)
            .preferredColorScheme(appState.theme.dark ? .dark : .light)
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
                    f("Gatekeeper", "Activé", .good),
                    f("SIP", "Activé", .good),
                    f("Pare-feu", "Désactivé", .warn),
                    f("XProtect", "À jour", .good),
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
