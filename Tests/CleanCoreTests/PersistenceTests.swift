import XCTest
@testable import CleanCore

final class PersistenceTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cleanmac-persist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: tmp) }

    // MARK: Schedule

    private func plist(_ s: ScanSchedule) throws -> [String: Any] {
        let data = try XCTUnwrap(ScheduledScanAgent.plistData(bundleID: "ai.test.app",
                                                              executablePath: "/Apps/CleanMacPro", schedule: s))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    func testDailyPlist() throws {
        let d = try plist(ScanSchedule(frequency: .daily, hour: 7, minute: 30))
        XCTAssertEqual(d["Label"] as? String, "ai.test.app.scheduled-scan")
        XCTAssertEqual(d["ProgramArguments"] as? [String], ["/Apps/CleanMacPro", "--scheduled-scan"])
        let i = try XCTUnwrap(d["StartCalendarInterval"] as? [String: Int])
        XCTAssertEqual(i, ["Hour": 7, "Minute": 30])
    }

    func testWeeklyPlistHasWeekday() throws {
        let d = try plist(ScanSchedule(frequency: .weekly, hour: 22, minute: 5, weekday: 7))
        let i = try XCTUnwrap(d["StartCalendarInterval"] as? [String: Int])
        XCTAssertEqual(i, ["Hour": 22, "Minute": 5, "Weekday": 7])
    }

    func testOffProducesNoPlistAndSyncRemovesFile() throws {
        XCTAssertNil(ScheduledScanAgent.plistData(bundleID: "x", executablePath: "/x", schedule: ScanSchedule()))
        let on = ScanSchedule(frequency: .daily)
        let url = try XCTUnwrap(ScheduledScanAgent.sync(bundleID: "ai.test.app", executablePath: "/x",
                                                        schedule: on, directory: tmp))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.lastPathComponent, "ai.test.app.scheduled-scan.plist")
        XCTAssertNil(try ScheduledScanAgent.sync(bundleID: "ai.test.app", executablePath: "/x",
                                                 schedule: ScanSchedule(), directory: tmp))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testScheduleClampsValues() {
        let s = ScanSchedule(frequency: .weekly, hour: 99, minute: -4, weekday: 12)
        XCTAssertEqual(s.hour, 23); XCTAssertEqual(s.minute, 0); XCTAssertEqual(s.weekday, 7)
    }

    // MARK: Exclusions

    private func item(_ path: String, kind: ItemKind = .cache) -> ScanItem {
        ScanItem(url: URL(fileURLWithPath: path), size: 10, kind: kind)
    }

    func testPathPrefixFilteringWithoutFalsePositive() {
        let ex = ExclusionList(paths: ["/a/b"])
        let kept = ex.apply(to: [item("/a/b"), item("/a/b/c.txt"), item("/a/bc"), item("/a/bc/d"), item("/a")])
        XCTAssertEqual(kept.map(\.url.path), ["/a/bc", "/a/bc/d", "/a"])
    }

    func testTrailingSlashNormalised() {
        var ex = ExclusionList()
        ex.addPath("/a/b/")
        ex.addPath("/a/b")
        XCTAssertEqual(ex.paths, ["/a/b"])
        XCTAssertTrue(ex.isExcluded(item("/a/b/x")))
    }

    func testAppIDExclusion() {
        let ex = ExclusionList(appIDs: ["com.foo.Bar"])
        let app = item("/Applications/Bar.app", kind: .app)
        let other = item("/Applications/Baz.app", kind: .app)
        let residue = item("/Users/u/Library/Caches/com.foo.bar/x", kind: .appResidue)
        let unrelated = item("/Users/u/Library/Caches/com.other/x", kind: .appResidue)
        let ids: (URL) -> String? = { $0.lastPathComponent == "Bar.app" ? "com.foo.Bar" : "com.baz" }
        let kept = ex.apply(to: [app, other, residue, unrelated], bundleID: ids)
        XCTAssertEqual(kept.map(\.url.path), ["/Applications/Baz.app", "/Users/u/Library/Caches/com.other/x"])
    }

    func testExclusionsRoundTripAndScanFiltered() async throws {
        let root = tmp.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("keep"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("skip"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 500).write(to: root.appendingPathComponent("keep/a"))
        try Data(repeating: 1, count: 500).write(to: root.appendingPathComponent("skip/b"))

        var ex = ExclusionList()
        ex.addPath(root.appendingPathComponent("skip").path)
        ex.addAppID("com.foo")
        try ex.save(to: tmp)
        let loaded = ExclusionList.load(from: tmp)
        XCTAssertEqual(loaded, ex)

        let r = try await CleanupScanner(rootOverrides: [root]).scanFiltered(exclusions: loaded) { _, _ in }
        XCTAssertEqual(r.count, 1)
        XCTAssertTrue(r.items[0].url.path.hasSuffix("keep/a"))
    }

    // MARK: History

    func testRecordCapAndRoundTrip() throws {
        var h = CleanHistory()
        for i in 0..<5 {
            h.record(HistoryEntry(module: "cleanup", itemCount: i, freedBytes: 100,
                                  records: [TrashRecord(originalPath: "/o\(i)", trashPath: "/t\(i)")]), limit: 3)
        }
        XCTAssertEqual(h.entries.count, 3)
        XCTAssertEqual(h.entries.first?.itemCount, 4)   // newest first
        XCTAssertEqual(h.totalFreedBytes, 300)
        try h.save(to: tmp)
        XCTAssertEqual(CleanHistory.load(from: tmp), h)
    }

    func testRecordFromReportIgnoresEmpty() {
        var h = CleanHistory()
        XCTAssertNil(h.record(module: "cleanup", report: CleanReport(removedCount: 0, freedBytes: 0, failedItems: [])))
        let rep = CleanReport(removedCount: 1, freedBytes: 42, failedItems: [],
                              trashed: [TrashRecord(originalPath: "/a", trashPath: "/t/a")])
        XCTAssertNotNil(h.record(module: "cleanup", report: rep))
        XCTAssertEqual(h.entries.count, 1)
    }

    func testRestoreMovesBackFromSimulatedTrash() throws {
        let fm = FileManager.default
        let trash = tmp.appendingPathComponent("trash")
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        let t1 = trash.appendingPathComponent("one.txt"), t2 = trash.appendingPathComponent("two.txt")
        try Data("1".utf8).write(to: t1)
        try Data("2".utf8).write(to: t2)
        let o1 = tmp.appendingPathComponent("deep/dir/one.txt")   // parent missing: recreated
        let o2 = tmp.appendingPathComponent("two.txt")
        try Data("occupied".utf8).write(to: o2)                   // destination taken
        let ghost = tmp.appendingPathComponent("gone.txt")

        let entry = HistoryEntry(module: "files", itemCount: 3, freedBytes: 3, records: [
            TrashRecord(originalPath: o1.path, trashPath: t1.path),
            TrashRecord(originalPath: o2.path, trashPath: t2.path),
            TrashRecord(originalPath: ghost.path, trashPath: trash.appendingPathComponent("nope").path),
        ])
        let out = CleanHistory.restore(entry)
        XCTAssertEqual(out.restored, [o1.path])
        XCTAssertEqual(out.destinationTaken, [o2.path])
        XCTAssertEqual(out.missingFromTrash, [ghost.path])
        XCTAssertTrue(fm.fileExists(atPath: o1.path))
        XCTAssertFalse(fm.fileExists(atPath: t1.path))
        XCTAssertTrue(fm.fileExists(atPath: t2.path))                    // untouched
        XCTAssertEqual(try String(contentsOf: o2), "occupied")
        XCTAssertFalse(out.message.isEmpty)
    }

    func testCleanerReportsTrashPathsWhenTrashAvailable() throws {
        let f = tmp.appendingPathComponent("victim.bin")
        try Data(repeating: 7, count: 64).write(to: f)
        // A personal file (large file) goes to the Trash; caches are deleted for good.
        let report = Cleaner.clean(items: [ScanItem(url: f, size: 64, kind: .largeFile)])
        guard report.failedItems.isEmpty else { throw XCTSkip("trashItem unavailable on this runner") }
        XCTAssertEqual(report.trashed.count, 1)
        XCTAssertEqual(report.trashed[0].originalPath, f.path)
        let entry = HistoryEntry(module: "cleanup", itemCount: 1, freedBytes: 64, records: report.trashed)
        let out = CleanHistory.restore(entry)
        XCTAssertEqual(out.restored, [f.path])
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.path))
    }
}
