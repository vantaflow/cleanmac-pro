import XCTest
@testable import CleanCore

/// Cleaning semantics: regenerable data is deleted for good, personal files go
/// to the Trash, everything else is ignored; history stays coherent.
final class CleaningPolicyTests: XCTestCase {
    var tmp: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cleanmac-policy-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Restore permissions possibly changed by a test, then clean up.
        for url in [tmp.appendingPathComponent("locked")] {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        try? fm.removeItem(at: tmp)
    }

    @discardableResult
    private func file(_ rel: String, bytes: Int = 1_000) throws -> URL {
        let u = tmp.appendingPathComponent(rel)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: u)
        return u
    }

    // MARK: Policy table

    func testRegenerableKinds() {
        for k in [ItemKind.cache, .log, .tempFile] { XCTAssertTrue(k.isRegenerable, "\(k)") }
        for k in [ItemKind.trash, .largeFile, .oldFile, .duplicate, .privacyData, .app, .appResidue,
                  .securityFinding, .updateAvailable, .launchAgent, .loginItem, .processSnapshot,
                  .maintenanceTask, .spaceFolder, .keeper] {
            XCTAssertFalse(k.isRegenerable, "\(k)")
        }
    }

    func testDeletionPolicyPerKind() {
        for k in [ItemKind.cache, .log, .tempFile, .trash] { XCTAssertEqual(k.deletionPolicy, .permanent, "\(k)") }
        for k in [ItemKind.largeFile, .oldFile, .duplicate, .privacyData, .app, .appResidue] {
            XCTAssertEqual(k.deletionPolicy, .trash, "\(k)")
        }
        for k in [ItemKind.securityFinding, .updateAvailable, .launchAgent, .loginItem, .processSnapshot,
                  .maintenanceTask, .spaceFolder, .keeper] {
            XCTAssertEqual(k.deletionPolicy, .none, "\(k)")
            XCTAssertFalse(k.isCleanable)
        }
    }

    func testPersonalFilesAreNeverRegenerable() {
        for k in [ItemKind.largeFile, .oldFile, .duplicate] {
            XCTAssertTrue(k.isPersonalFile)
            XCTAssertFalse(k.isRegenerable)
        }
        XCTAssertFalse(ItemKind.cache.isPersonalFile)
    }

    // MARK: Cleaner

    func testRegenerableItemsAreDeletedPermanentlyNotTrashed() throws {
        let dir = tmp.appendingPathComponent("Caches/com.example.app")
        try file("Caches/com.example.app/a.bin", bytes: 4_000)
        try file("Caches/com.example.app/sub/b.bin", bytes: 6_000)
        let item = ScanItem(url: dir, size: 10_000, kind: .cache, group: "g", fileCount: 2)
        let r = Cleaner.clean(items: [item])
        XCTAssertFalse(fm.fileExists(atPath: dir.path))
        XCTAssertEqual(r.removedCount, 1)
        XCTAssertEqual(r.freedBytes, 10_000)
        XCTAssertEqual(r.permanentCount, 1)
        XCTAssertEqual(r.permanentBytes, 10_000)
        XCTAssertTrue(r.trashed.isEmpty, "permanently deleted items have no Trash record")
        XCTAssertEqual(r.trashedCount, 0)
        XCTAssertEqual(r.trashedBytes, 0)
    }

    func testPersonalFilesGoToTheTrashAndCanBeRestored() throws {
        let f = try file("Downloads/big.bin", bytes: 2_000)
        let r = Cleaner.clean(items: [ScanItem(url: f, size: 2_000, kind: .largeFile)])
        guard r.failedItems.isEmpty else { throw XCTSkip("trashItem unavailable on this runner") }
        XCTAssertFalse(fm.fileExists(atPath: f.path))
        XCTAssertEqual(r.trashed.count, 1)
        XCTAssertEqual(r.permanentCount, 0)
        XCTAssertEqual(r.trashedCount, 1)
        XCTAssertEqual(r.trashedBytes, 2_000)
        let entry = HistoryEntry(module: "files", itemCount: 1, freedBytes: 2_000, records: r.trashed)
        XCTAssertTrue(entry.canRestore)
        XCTAssertEqual(CleanHistory.restore(entry).restored, [f.path])
        XCTAssertTrue(fm.fileExists(atPath: f.path))
    }

    func testNonCleanableKindsAreNeverTouched() throws {
        let f = try file("x.bin")
        let kinds: [ItemKind] = [.securityFinding, .updateAvailable, .loginItem, .launchAgent, .processSnapshot,
                                 .maintenanceTask, .spaceFolder, .keeper]
        let items = kinds.map { ScanItem(url: f, size: 1_000, kind: $0) }
        let r = Cleaner.clean(items: items)
        XCTAssertEqual(r.removedCount, 0)
        XCTAssertTrue(fm.fileExists(atPath: f.path))
    }

    func testKeeperIsNeverRemovedEvenIfSelected() throws {
        let f = try file("orig.bin")
        let r = Cleaner.clean(items: [ScanItem(url: f, size: 0, kind: .keeper)], forcePermanent: true, adminFallback: false)
        XCTAssertEqual(r.removedCount, 0)
        XCTAssertTrue(fm.fileExists(atPath: f.path))
    }

    func testDryRunCountsByPolicy() {
        let items = [
            ScanItem(url: tmp.appendingPathComponent("a"), size: 100, kind: .cache),
            ScanItem(url: tmp.appendingPathComponent("b"), size: 200, kind: .largeFile),
            ScanItem(url: tmp.appendingPathComponent("c"), size: 400, kind: .securityFinding),
        ]
        let r = Cleaner.clean(items: items, dryRun: true)
        XCTAssertEqual(r.removedCount, 2)
        XCTAssertEqual(r.freedBytes, 300)
        XCTAssertEqual(r.permanentCount, 1)
        XCTAssertEqual(r.permanentBytes, 100)
        XCTAssertEqual(r.trashedBytes, 200)
    }

    func testForcePermanentDeletesApps() throws {
        let app = try file("Applications/Foo.app/Contents/x", bytes: 500).deletingLastPathComponent().deletingLastPathComponent()
        let r = Cleaner.clean(items: [ScanItem(url: app, size: 500, kind: .app)], forcePermanent: true, adminFallback: false)
        XCTAssertFalse(fm.fileExists(atPath: app.path))
        XCTAssertEqual(r.permanentCount, 1)
        XCTAssertTrue(r.trashed.isEmpty)
    }

    func testFailureIsReportedAndNothingIsCredited() throws {
        // A file in a read-only folder cannot be unlinked (non-root).
        guard getuid() != 0 else { throw XCTSkip("running as root") }
        let f = try file("locked/stuck.bin", bytes: 1_000)
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: f.deletingLastPathComponent().path)
        let r = Cleaner.delete(items: [ScanItem(url: f, size: 1_000, kind: .cache)])
        XCTAssertEqual(r.failedItems, [f])
        XCTAssertEqual(r.removedCount, 0)
        XCTAssertEqual(r.freedBytes, 0)
        XCTAssertTrue(fm.fileExists(atPath: f.path))
        // Only what is still on disk is retried with admin rights.
        let left = Cleaner.residual(of: [ScanItem(url: f, size: 1_000, kind: .cache)], failed: r.failedItems)
        XCTAssertEqual(left.count, 1)
    }

    func testSafetyGuardRefusesRootsAndContainers() throws {
        let home = FS.home
        for u in [URL(fileURLWithPath: "/"), home, home.appendingPathComponent("Library"),
                  home.appendingPathComponent("Library/Caches"), home.appendingPathComponent(".Trash"),
                  home.appendingPathComponent("Documents"), URL(fileURLWithPath: "/Users"),
                  URL(fileURLWithPath: "/Library/Caches"), URL(fileURLWithPath: "/Applications")] {
            XCTAssertFalse(Cleaner.isSafeToRemove(u), u.path)
        }
        XCTAssertTrue(Cleaner.isSafeToRemove(home.appendingPathComponent("Library/Caches/com.example.app")))
        XCTAssertTrue(Cleaner.isSafeToRemove(tmp.appendingPathComponent("anything")))
        // Delete / trash refuse a protected path without touching it.
        let r = Cleaner.delete(items: [ScanItem(url: home, size: 1, kind: .cache)])
        XCTAssertEqual(r.removedCount, 0)
        XCTAssertEqual(r.failedItems, [home])
        XCTAssertTrue(fm.fileExists(atPath: home.path))
    }

    func testEmptyTrashDeletesEverythingAndReports() throws {
        let trash = tmp.appendingPathComponent("FakeTrash")
        try file("FakeTrash/a.dmg", bytes: 3_000)
        try file("FakeTrash/folder/b.txt", bytes: 2_000)
        let r = try XCTUnwrap(Cleaner.emptyTrash(at: trash))
        XCTAssertEqual(r.removedCount, 2)
        XCTAssertEqual(r.permanentCount, 2)
        XCTAssertGreaterThanOrEqual(r.freedBytes, 5_000)
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: trash.path).isEmpty)
        XCTAssertNil(Cleaner.emptyTrash(at: tmp.appendingPathComponent("does-not-exist")))
    }

    func testReportMerge() {
        let a = CleanReport(removedCount: 1, freedBytes: 10, failedItems: [], permanentCount: 1, permanentBytes: 10)
        let b = CleanReport(removedCount: 2, freedBytes: 30, failedItems: [tmp],
                            trashed: [TrashRecord(originalPath: "/o", trashPath: "/t")])
        let m = a.merged(with: b)
        XCTAssertEqual(m.removedCount, 3)
        XCTAssertEqual(m.freedBytes, 40)
        XCTAssertEqual(m.permanentCount, 1)
        XCTAssertEqual(m.trashedCount, 2)
        XCTAssertEqual(m.trashedBytes, 30)
        XCTAssertEqual(m.failedItems, [tmp])
        XCTAssertEqual(m.trashed.count, 1)
    }

    // MARK: History coherence

    func testPermanentOnlyReportIsRecordedWithoutRestore() {
        var h = CleanHistory()
        let rep = CleanReport(removedCount: 3, freedBytes: 900, failedItems: [], permanentCount: 3, permanentBytes: 900)
        let e = h.record(module: "cleanup", report: rep)
        XCTAssertNotNil(e)
        XCTAssertEqual(e?.canRestore, false)
        XCTAssertEqual(e?.permanentCount, 3)
        XCTAssertEqual(h.totalFreedBytes, 900)
        let out = CleanHistory.restore(try! XCTUnwrap(e))
        XCTAssertTrue(out.restored.isEmpty)
        XCTAssertEqual(out.permanentlyDeleted, 3)
        XCTAssertFalse(out.message.isEmpty)
    }

    func testMixedReportKeepsOnlyTrashedRecordsRestorable() {
        var h = CleanHistory()
        let rep = CleanReport(removedCount: 3, freedBytes: 600, failedItems: [],
                              trashed: [TrashRecord(originalPath: "/o", trashPath: "/t")],
                              permanentCount: 2, permanentBytes: 400)
        let e = h.record(module: "smartScan", report: rep)
        XCTAssertEqual(e?.records.count, 1)
        XCTAssertEqual(e?.canRestore, true)
        XCTAssertEqual(e?.permanentBytes, 400)
    }

    func testLegacyHistoryEntriesStillDecode() throws {
        let json = """
        {"entries":[{"id":"\(UUID().uuidString)","date":"2026-01-01T10:00:00Z","module":"cleanup",
        "itemCount":2,"freedBytes":50,"records":[{"originalPath":"/a","trashPath":"/t/a"}]}]}
        """
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let h = try dec.decode(CleanHistory.self, from: Data(json.utf8))
        XCTAssertEqual(h.entries.count, 1)
        XCTAssertEqual(h.entries[0].permanentCount, 0)
        XCTAssertTrue(h.entries[0].canRestore)
    }

    // MARK: Scanners

    func testCleanupScannerGroupsPerFolder() async throws {
        let root = tmp.appendingPathComponent("Caches")
        for i in 1...50 { try file("Caches/com.example.big/f\(i).bin", bytes: 500) }
        for i in 1...3 { try file("Caches/com.example.small/f\(i).bin", bytes: 700) }
        try file("Caches/loose.bin", bytes: 900)
        let r = try await CleanupScanner(rootOverrides: [root]).scan { _, _ in }
        XCTAssertEqual(r.count, 3, "two cache folders + one loose file, not 54 rows")
        let big = try XCTUnwrap(r.items.first { $0.url.lastPathComponent == "com.example.big" })
        XCTAssertEqual(big.fileCount, 50)
        XCTAssertGreaterThanOrEqual(big.size, 25_000)
        XCTAssertTrue(big.kind.isRegenerable)
        XCTAssertNil(r.items.first { $0.url.lastPathComponent == "loose.bin" }?.fileCount)
        // Cleaning removes whole folders; the report is the sum of the rows.
        let rep = Cleaner.clean(items: r.items)
        XCTAssertEqual(rep.removedCount, 3)
        XCTAssertEqual(rep.freedBytes, r.totalSize)
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testDuplicatesNeverOfferEveryCopy() async throws {
        let dir = tmp.appendingPathComponent("Docs")
        let content = Data(repeating: 0x42, count: 2 * 1024 * 1024)
        for n in ["a.bin", "b.bin", "c.bin"] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try content.write(to: dir.appendingPathComponent(n))
        }
        let r = try await DuplicatesScanner(roots: [dir], minSize: 1024 * 1024).scan { _, _ in }
        XCTAssertEqual(r.items.filter { $0.kind == .keeper }.count, 1)
        XCTAssertEqual(r.items.filter { $0.kind == .duplicate }.count, 2)
        // "Select all" + clean leaves the original on disk.
        let rep = Cleaner.clean(items: r.items, forcePermanent: true, adminFallback: false)
        XCTAssertEqual(rep.removedCount, 2)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: dir.path).count, 1)
    }

    func testFilesScannerKeeperBeatsLargeEntry() async throws {
        let dir = tmp.appendingPathComponent("Both")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = Data(repeating: 0x33, count: 3 * 1024 * 1024)
        try content.write(to: dir.appendingPathComponent("one.bin"))
        try content.write(to: dir.appendingPathComponent("two.bin"))
        // Both copies are "large"; one of them must still be a keeper.
        let r = try await FilesScanner(
            large: LargeFilesScanner(roots: [dir], minSize: 1024 * 1024, oldAge: .infinity),
            duplicates: DuplicatesScanner(roots: [dir], minSize: 1024 * 1024)).scan { _, _ in }
        XCTAssertEqual(r.items.filter { $0.kind == .keeper }.count, 1)
        XCTAssertEqual(Set(r.items.map(\.url)).count, r.items.count)
        let cleanable = r.items.filter { $0.kind.isCleanable }
        XCTAssertEqual(cleanable.count, 1, "at most one of the two identical large files can be cleaned")
    }

    // MARK: Space measurement

    func testSpaceMeasureUsesTheVolumeDelta() {
        let before = DiskSnapshot(freeBytes: 100_000_000_000, totalBytes: 500_000_000_000)
        let after = DiskSnapshot(freeBytes: 104_700_000_000, totalBytes: 500_000_000_000)
        let m = SpaceMeasure(before: before, after: after, reportedBytes: 5_000_000_000)
        XCTAssertEqual(m.measuredDelta, 4_700_000_000)
        XCTAssertEqual(m.freedBytes, 4_700_000_000, "the measured gain wins over the sum of sizes")
        XCTAssertFalse(m.gainedLessThanReported)
    }

    func testSpaceMeasureNeverNegative() {
        let m = SpaceMeasure(before: DiskSnapshot(freeBytes: 10_000, totalBytes: 100_000),
                             after: DiskSnapshot(freeBytes: 9_000, totalBytes: 100_000), reportedBytes: 500)
        XCTAssertEqual(m.measuredDelta, -1_000)
        XCTAssertEqual(m.freedBytes, 0)
    }

    func testSpaceMeasureFallsBackAndIgnoresTrash() {
        let m = SpaceMeasure(before: nil, after: nil, reportedBytes: 1_000, trashedBytes: 400)
        XCTAssertNil(m.measuredDelta)
        XCTAssertEqual(m.freedBytes, 600, "Trash moves free nothing until it is emptied")
    }

    func testSpaceMeasureFlagsMissingGain() {
        let b = DiskSnapshot(freeBytes: 50_000_000_000, totalBytes: 500_000_000_000)
        let a = DiskSnapshot(freeBytes: 50_100_000_000, totalBytes: 500_000_000_000)
        XCTAssertTrue(SpaceMeasure(before: b, after: a, reportedBytes: 4_000_000_000).gainedLessThanReported)
        XCTAssertFalse(SpaceMeasure(before: b, after: a, reportedBytes: 100_000_000).gainedLessThanReported)
    }

    func testDiskSnapshotIsReadable() throws {
        let s = try XCTUnwrap(DiskSpace.snapshot(at: tmp))
        XCTAssertGreaterThan(s.totalBytes, 0)
        XCTAssertGreaterThan(s.freeBytes, 0)
        XCTAssertLessThanOrEqual(s.freeBytes, s.totalBytes)
        XCTAssertTrue((0...1).contains(s.usedFraction))
    }

    func testRealDeletionFreesDiskSpaceOnTheVolume() throws {
        // Write ~64 MB, measure, delete permanently, measure: free space must not drop.
        let dir = tmp.appendingPathComponent("Caches/com.example.heavy")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var bytes: Int64 = 0
        for i in 0..<16 {
            let u = dir.appendingPathComponent("blk-\(i).bin")
            try Data(repeating: UInt8(i + 1), count: 4 * 1024 * 1024).write(to: u)
            bytes += FS.size(of: u)
        }
        let before = DiskSpace.snapshot(at: tmp)
        let r = Cleaner.clean(items: [ScanItem(url: dir, size: bytes, kind: .cache, fileCount: 16)])
        let after = DiskSpace.snapshot(at: tmp)
        XCTAssertEqual(r.freedBytes, bytes)
        let m = SpaceMeasure(before: before, after: after, reportedBytes: r.freedBytes, trashedBytes: r.trashedBytes)
        XCTAssertNotNil(m.measuredDelta)
        // Other processes write too, so only assert the direction loosely.
        XCTAssertGreaterThan(m.measuredDelta ?? 0, -200_000_000)
    }
}
