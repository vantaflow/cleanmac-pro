import XCTest
@testable import CleanCore

/// Smart Care decisions: default selection and what "Lancer" may run.
final class SmartCareTests: XCTestCase {
    private func item(_ name: String, _ kind: ItemKind, size: Int64 = 1_000, group: String? = nil,
                      severity: Severity = .info, command: String? = nil,
                      release: SparkleRelease? = nil) -> ScanItem {
        ScanItem(url: URL(fileURLWithPath: "/fake/\(name)"), size: size, kind: kind, group: group,
                 title: name, severity: severity, command: command, sparkleRelease: release)
    }

    private struct World {
        var cleanup: [ScanItem], developer: [ScanItem], files: [ScanItem], privacy: [ScanItem]
        var security: [ScanItem], updates: [ScanItem], performance: [ScanItem]
    }

    private func world() -> World {
        let release = SparkleRelease(shortVersion: "2", build: "2", downloadURL: URL(string: "https://example.invalid/x.zip"))
        return World(
            cleanup: [item("c1", .cache, size: 4_000), item("c2", .cache, size: 6_000), item("l1", .log, size: 500),
                      item("t1", .tempFile, size: 700), item("trash1", .trash, size: 9_000)],
            developer: [item("derived", .cache, size: 20_000), item("archive", .oldFile, size: 3_000)],
            files: [item("big", .largeFile, size: 50_000), item("old", .oldFile, size: 8_000),
                    item("dup", .duplicate, size: 2_000), item("orig", .keeper, size: 0)],
            privacy: [item("Firefox", .privacyData, size: 7_000)],
            security: [item("FileVault", .securityFinding, severity: .good),
                       item("Pare-feu", .securityFinding, severity: .warn, group: "Système"),
                       item("evil.plist", .securityFinding, severity: .bad, group: L("Menaces"))],
            updates: [item("A", .updateAvailable, severity: .warn, release: release),
                      item("B", .updateAvailable, severity: .warn),
                      item("C", .updateAvailable, severity: .good)],
            performance: [item("Spotify", .loginItem, command: "true"), item("none", .loginItem, severity: .good)])
    }

    private func results(_ w: World) -> [ModuleID: ScanResult] {
        [.cleanup: ScanResult(module: .cleanup, items: w.cleanup),
         .developer: ScanResult(module: .developer, items: w.developer),
         .files: ScanResult(module: .files, items: w.files),
         .privacy: ScanResult(module: .privacy, items: w.privacy),
         .security: ScanResult(module: .security, items: w.security),
         .updates: ScanResult(module: .updates, items: w.updates),
         .performance: ScanResult(module: .performance, items: w.performance)]
    }

    /// Selections as the app builds them right after a scan.
    private func defaultSelections(_ r: [ModuleID: ScanResult]) -> [ModuleID: Set<UUID>] {
        var s: [ModuleID: Set<UUID>] = [:]
        for (m, res) in r { s[m] = SmartCarePlan.defaultSelection(for: m, items: res.items) }
        return s
    }

    // MARK: Default selection

    func testDefaultSelectionIsRegenerableOnly() {
        let w = world()
        let cleanupSel = SmartCarePlan.defaultSelection(for: .cleanup, items: w.cleanup)
        XCTAssertEqual(cleanupSel, Set(w.cleanup.filter { $0.kind != .trash }.map(\.id)), "Trash is not ticked")
        let devSel = SmartCarePlan.defaultSelection(for: .developer, items: w.developer)
        XCTAssertEqual(devSel, Set([w.developer[0].id]), "developer caches yes, old archives no")
        for m in [ModuleID.files, .similarPhotos, .privacy, .security, .updates, .performance, .uninstaller] {
            XCTAssertTrue(SmartCarePlan.defaultSelection(for: m, items: w.files + w.privacy).isEmpty, "\(m)")
        }
    }

    func testDefaultRunContainsNoPersonalFileBrowserDataOrTrash() {
        let w = world(), r = results(w)
        let plan = SmartCarePlan(results: r, selections: defaultSelections(r))
        let run = plan.runnableItems
        XCTAssertFalse(run.isEmpty)
        XCTAssertTrue(run.allSatisfy { $0.kind.isRegenerable })
        XCTAssertFalse(run.contains { $0.kind.isPersonalFile || $0.kind == .privacyData || $0.kind == .trash })
        XCTAssertEqual(plan.runnableBytes, 4_000 + 6_000 + 500 + 700 + 20_000)
        XCTAssertEqual(plan.runnablePermanentBytes, plan.runnableBytes)
        XCTAssertEqual(plan.runnableTrashBytes, 0)
        XCTAssertTrue(plan.selectedClutter.isEmpty)
        XCTAssertTrue(plan.selectedPrivacy.isEmpty)
        XCTAssertFalse(plan.trashSelected)
        XCTAssertTrue(plan.hasWork)
    }

    func testNothingSelectedMeansNothingToRun() {
        let r = results(world())
        let plan = SmartCarePlan(results: r, selections: [:])
        XCTAssertTrue(plan.runnableItems.isEmpty)
        XCTAssertFalse(plan.hasWork)
        XCTAssertEqual(plan.selectedRegenerableBytes, 0)
    }

    // MARK: Explicit review

    func testExplicitSelectionIsRunButNeverNonCleanableRows() {
        let w = world(), r = results(w)
        var sel = defaultSelections(r)
        sel[.files] = Set(w.files.map(\.id))                  // "select all", keeper included
        sel[.privacy] = Set(w.privacy.map(\.id))
        sel[.cleanup, default: []].formUnion(w.cleanup.filter { $0.kind == .trash }.map(\.id))
        sel[.security] = Set(w.security.map(\.id))            // findings can't be cleaned
        sel[.updates] = Set(w.updates.map(\.id))
        let plan = SmartCarePlan(results: r, selections: sel)
        let kinds = Set(plan.runnableItems.map(\.kind))
        XCTAssertTrue(kinds.isSuperset(of: [.largeFile, .oldFile, .duplicate, .privacyData, .trash, .cache]))
        XCTAssertFalse(kinds.contains(.keeper))
        XCTAssertFalse(kinds.contains(.securityFinding))
        XCTAssertFalse(kinds.contains(.updateAvailable))
        XCTAssertTrue(plan.trashSelected)
        XCTAssertEqual(plan.selectedClutter.count, 3)
        XCTAssertEqual(plan.selectedPrivacy.count, 1)
        XCTAssertEqual(plan.runnableTrashBytes, 50_000 + 8_000 + 2_000 + 7_000)
        XCTAssertGreaterThan(plan.runnablePermanentBytes, 0)
    }

    func testRunIsDedupedByURL() {
        let a = item("same", .cache), b = item("same", .cache)
        let r: [ModuleID: ScanResult] = [.cleanup: ScanResult(module: .cleanup, items: [a]),
                                         .developer: ScanResult(module: .developer, items: [b])]
        let plan = SmartCarePlan(results: r, selections: [.cleanup: [a.id], .developer: [b.id]])
        XCTAssertEqual(plan.runnableItems.count, 1)
    }

    func testSelectionOfAnUnknownIdRunsNothing() {
        let r = results(world())
        let plan = SmartCarePlan(results: r, selections: [.files: [UUID()]])
        XCTAssertTrue(plan.runnableItems.isEmpty)
    }

    // MARK: Card figures

    func testCardFigures() {
        let w = world(), r = results(w)
        let plan = SmartCarePlan(results: r, selections: defaultSelections(r))
        XCTAssertEqual(plan.regenerableBytes, 4_000 + 6_000 + 500 + 700 + 20_000)
        XCTAssertEqual(plan.regenerableBytes(kind: .cache, module: .cleanup), 10_000)
        XCTAssertEqual(plan.regenerableBytes(kind: .log, module: .cleanup), 500)
        XCTAssertEqual(plan.regenerableBytes(kind: .tempFile, module: .cleanup), 700)
        XCTAssertEqual(plan.developerCacheBytes, 20_000)
        XCTAssertEqual(plan.trashBytes, 9_000)
        XCTAssertEqual(plan.threats.count, 1)
        XCTAssertEqual(plan.settingsToCheck.count, 1)
        XCTAssertEqual(plan.securityIssues.count, 2)
        XCTAssertEqual(plan.privacyBytes, 7_000)
        XCTAssertEqual(plan.performanceTasks.count, 1)
        XCTAssertEqual(plan.updates.count, 2, "up-to-date rows don't count")
        XCTAssertEqual(plan.installableUpdates.count, 1)
        XCTAssertEqual(plan.clutterBytes, 50_000 + 8_000 + 2_000, "the kept original is not clutter")
    }

    func testCategories() {
        XCTAssertEqual(SmartCareCategory.allCases.count, 5)
        XCTAssertEqual(SmartCareCategory.cleanup.reviewModule, .cleanup)
        XCTAssertEqual(SmartCareCategory.clutter.reviewModule, .files)
        XCTAssertEqual(SmartCareCategory.applications.reviewModule, .updates)
        for c in SmartCareCategory.allCases { XCTAssertFalse(c.title.isEmpty) }
        for m in ModuleID.allCases {
            XCTAssertFalse(m.title.isEmpty); XCTAssertFalse(m.subtitle.isEmpty); XCTAssertFalse(m.symbol.isEmpty)
        }
        XCTAssertTrue(ModuleID.allCases.contains(.history))
    }

    // MARK: End to end on disk

    func testLancerOnAFixtureTreeDeletesOnlyTheSafeDefaults() async throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cleanmac-smartcare-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        func write(_ rel: String, _ n: Int) throws -> URL {
            let u = root.appendingPathComponent(rel)
            try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 0x5A, count: n).write(to: u)
            return u
        }
        let caches = root.appendingPathComponent("Caches")
        for i in 1...5 { _ = try write("Caches/com.example.a/f\(i)", 2_000) }
        for i in 1...5 { _ = try write("Caches/com.example.b/f\(i)", 3_000) }
        let personal = try write("Downloads/important.bin", 200_000)
        let browser = try write("Browser/Cookies", 5_000)

        let cleanup = try await CleanupScanner(rootOverrides: [caches]).scan { _, _ in }
        let files = ScanResult(module: .files, items: [
            ScanItem(url: personal, size: 200_000, kind: .largeFile)])
        let priv = ScanResult(module: .privacy, items: [ScanItem(url: browser, size: 5_000, kind: .privacyData)])
        let r: [ModuleID: ScanResult] = [.cleanup: cleanup, .files: files, .privacy: priv]
        let plan = SmartCarePlan(results: r, selections: defaultSelections(r))

        let before = DiskSpace.snapshot(at: root)
        let report = Cleaner.clean(items: plan.runnableItems)
        let after = DiskSpace.snapshot(at: root)

        XCTAssertEqual(report.removedCount, 2)
        XCTAssertEqual(report.permanentCount, 2)
        XCTAssertTrue(report.trashed.isEmpty)
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: caches.path).isEmpty)
        XCTAssertTrue(fm.fileExists(atPath: personal.path), "personal files survive an unreviewed run")
        XCTAssertTrue(fm.fileExists(atPath: browser.path), "browser data survives an unreviewed run")
        let m = SpaceMeasure(before: before, after: after, reportedBytes: report.freedBytes, trashedBytes: report.trashedBytes)
        XCTAssertEqual(m.reportedBytes, plan.runnablePermanentBytes)
    }
}
