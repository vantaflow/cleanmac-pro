import SwiftUI
import AppKit
import CleanCore

/// Built-in UI test mode (`--ui-test [--ui-test-out <dir>]`), driven by CI on a
/// macOS runner with a graphical session. It skips the onboarding, walks every
/// screen (all `ModuleID` cases, the settings window, the menu-bar popover),
/// writes one PNG per screen plus `report.json`, then quits.
///
/// Safety: it never calls `clean(...)`, never runs maintenance commands and
/// never asks for admin rights. Scans only read a throw-away fixture tree
/// created inside the output directory (the Result screen is fed a synthetic
/// report, nothing is removed).
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
        if let i = args.firstIndex(of: "--ui-test-out"), i + 1 < args.count {
            outDir = URL(fileURLWithPath: args[i + 1])
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

    private func fail(_ message: String) { report.errors.append(message) }

    private func finish() {
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
        // Fixture trees (inside the output dir; read-only for the scanners).
        let fixture = outDir.appendingPathComponent("fixture", isDirectory: true)
        let cleanupRoot = fixture.appendingPathComponent("Caches", isDirectory: true)
        let lensRoot = fixture.appendingPathComponent("Lens", isDirectory: true)
        makeFixture(cleanupRoot: cleanupRoot, lensRoot: lensRoot)

        appState.scannerOverrides = [
            .cleanup: CleanupScanner(rootOverrides: [cleanupRoot]),
            .smartScan: SmartScanner(rootOverrides: [cleanupRoot]),
            .spaceLens: SpaceLensScanner(roots: [lensRoot]),
        ]
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
            if module == .result { seedResult() }
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            record(window: main, id: module.rawValue, title: module.title,
                   file: "screen-\(module.rawValue).png", distinct: module != .dashboard)
        }

        // 4. Real scans on fixtures: Cleanup, Space Lens, Smart Scan.
        appState.active = .cleanup
        appState.startScan(module: .cleanup)
        if await waitForScan(.cleanup) {
            let n = appState.state(for: .cleanup).result?.items.count ?? 0
            report.cleanupFixtureItems = n
            if n == 0 { fail("cleanup scan on fixture returned no rows") }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            record(window: main, id: "cleanup-scanned", title: "Nettoyage (scan fixture)",
                   file: "screen-cleanup-scanned.png", distinct: true)
        }

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

        appState.active = .smartScan
        appState.startScan(module: .smartScan)
        if await waitForScan(.smartScan) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            record(window: main, id: "smartScan-scanned", title: "Smart Scan (scan fixture)",
                   file: "screen-smartScan-scanned.png", distinct: false)
        }

        // 5. Settings window.
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if let settings = NSApp.windows.first(where: {
            $0 !== main && $0.isVisible && $0.styleMask.contains(.titled) && $0.contentView != nil
        }) {
            record(window: settings, id: "settings", title: "Réglages",
                   file: "screen-settings.png", distinct: false)
            settings.close()
        } else {
            report.screens.append(ScreenReport(id: "settings", title: "Réglages",
                                               error: "settings window did not open"))
            fail("settings window did not open")
        }

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
        fail("windows: " + windowDump())
        return nil
    }

    private func waitForScan(_ module: ModuleID) async -> Bool {
        for _ in 0..<240 {
            let s = appState.state(for: module)
            if !s.isScanning && s.result != nil { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        fail("\(module.rawValue) scan did not finish within 120 s")
        return false
    }

    private func makeFixture(cleanupRoot: URL, lensRoot: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: outDir.appendingPathComponent("fixture"))
        func write(_ dir: URL, _ name: String, kb: Int) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try? Data(repeating: 0x41, count: kb * 1024).write(to: dir.appendingPathComponent(name))
        }
        for app in ["com.example.alpha", "com.example.beta", "com.example.gamma"] {
            for i in 1...4 { write(cleanupRoot.appendingPathComponent(app), "cache-\(i).bin", kb: 40 * i) }
        }
        for (dir, kb) in [("Videos", 900), ("Photos", 600), ("Docs", 250), ("Archive", 120)] {
            for i in 1...3 { write(lensRoot.appendingPathComponent(dir), "file-\(i).dat", kb: kb) }
        }
    }

    /// Synthetic "cleanup done" report so the Result screen has content.
    /// Nothing is deleted: only in-memory state changes.
    private func seedResult() {
        let r = CleanReport(removedCount: 42, freedBytes: 3_400_000_000, failedItems: [])
        appState.update(.cleanup) { $0.lastReport = r }
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
        // Content area: skip the 264 pt sidebar for the main window.
        let isMain = window.frame.width >= 900
        s.edgePixels = edgePixels(rep, skipLeft: isMain ? 264 : 0)
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
