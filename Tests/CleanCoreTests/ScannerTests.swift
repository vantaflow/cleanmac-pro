import XCTest
@testable import CleanCore

final class ScannerTests: XCTestCase {

    var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cleanmac-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func createFile(name: String, bytes: Int, in dir: URL? = nil) throws -> URL {
        let parent = dir ?? tempRoot!
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let url = parent.appendingPathComponent(name)
        let data = Data(repeating: 0xAB, count: bytes)
        try data.write(to: url)
        return url
    }

    func testByteFormatterReadable() {
        // 0 renders as a localized "zero bytes" phrase (no literal "0" in
        // every locale), so just assert it produces non-empty, sane output.
        XCTAssertFalse(ByteFormatter.string(0).isEmpty)
        XCTAssertFalse(ByteFormatter.string(1_500_000).isEmpty)
        // Unit label is locale-dependent ("MB" / "Mo"), so assert on the digits.
        XCTAssertTrue(ByteFormatter.string(1_500_000).contains("1"))
        // Negative byte counts are clamped to 0, never rendered as "-".
        XCTAssertFalse(ByteFormatter.string(-42).contains("-"))
    }

    func testFSEnumerateFindsFiles() throws {
        let sub = tempRoot.appendingPathComponent("sub")
        _ = try createFile(name: "a.txt", bytes: 100)
        _ = try createFile(name: "b.txt", bytes: 200, in: sub)
        let files = Array(FS.enumerate(tempRoot))
        XCTAssertEqual(files.count, 2)
    }

    func testFSSize() throws {
        let u = try createFile(name: "size.bin", bytes: 4096)
        XCTAssertGreaterThanOrEqual(FS.size(of: u), 4096)
    }

    func testSmartScannerWithOverrides() async throws {
        let cacheDir = tempRoot.appendingPathComponent("Caches")
        _ = try createFile(name: "cache1.dat", bytes: 1000, in: cacheDir)
        _ = try createFile(name: "cache2.dat", bytes: 2000, in: cacheDir)

        let scanner = SmartScanner(rootOverrides: [cacheDir])
        let result = try await scanner.scan { _, _ in }
        XCTAssertEqual(result.module, .smartScan)
        XCTAssertEqual(result.count, 2)
        XCTAssertGreaterThan(result.totalSize, 0)
    }

    func testScanCacheFreshnessAndInvalidation() async throws {
        let cache = ScanCache()
        let dir = tempRoot.appendingPathComponent("Cacheable")
        _ = try createFile(name: "a.dat", bytes: 100, in: dir)
        let items = [ScanItem(url: dir, size: 100, kind: .cache, group: "x")]

        let t0 = Date()
        await cache.save(.smartScan, roots: [dir], items: items, now: t0)

        // Fresh + unchanged roots → hit.
        let hit = await cache.cached(.smartScan, roots: [dir], maxAge: 600, now: t0.addingTimeInterval(60))
        XCTAssertEqual(hit?.count, 1)

        // Past maxAge → miss.
        let stale = await cache.cached(.smartScan, roots: [dir], maxAge: 600, now: t0.addingTimeInterval(601))
        XCTAssertNil(stale)

        // Root mtime changed → miss even when fresh.
        _ = try createFile(name: "b.dat", bytes: 100, in: dir)
        let changed = await cache.cached(.smartScan, roots: [dir], maxAge: 600, now: t0.addingTimeInterval(60))
        XCTAssertNil(changed)
    }

    func testLargeFilesScanner() async throws {
        let dir = tempRoot.appendingPathComponent("Downloads")
        _ = try createFile(name: "small.dat", bytes: 100, in: dir)
        _ = try createFile(name: "huge.dat", bytes: 60 * 1024 * 1024, in: dir)

        let scanner = LargeFilesScanner(roots: [dir], minSize: 50 * 1024 * 1024, oldAge: .infinity)
        let result = try await scanner.scan { _, _ in }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.items.first?.kind, .largeFile)
    }

    func testDuplicatesScanner() async throws {
        let dir = tempRoot.appendingPathComponent("Docs")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Two identical files of 2 MB
        let content = Data(repeating: 0x42, count: 2 * 1024 * 1024)
        try content.write(to: dir.appendingPathComponent("copy1.bin"))
        try content.write(to: dir.appendingPathComponent("copy2.bin"))
        // Unique file
        try Data(repeating: 0x01, count: 2 * 1024 * 1024).write(to: dir.appendingPathComponent("unique.bin"))

        let scanner = DuplicatesScanner(roots: [dir], minSize: 1024 * 1024)
        let result = try await scanner.scan { _, _ in }
        XCTAssertEqual(result.count, 2, "Should detect 2 files in the duplicate group")
        let groups = Set(result.items.compactMap { $0.group?.split(separator: " ").first.map(String.init) })
        XCTAssertEqual(groups.count, 1, "Both items should share the same hash prefix group")
    }

    func testFilesScannerMergesLargeAndDuplicates() async throws {
        let dir = tempRoot.appendingPathComponent("Merge")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // One large, unique file
        _ = try createFile(name: "huge.dat", bytes: 60 * 1024 * 1024, in: dir)
        // Two identical small files → a duplicate group
        let content = Data(repeating: 0x7E, count: 2 * 1024 * 1024)
        try content.write(to: dir.appendingPathComponent("dupA.bin"))
        try content.write(to: dir.appendingPathComponent("dupB.bin"))

        let scanner = FilesScanner(
            large: LargeFilesScanner(roots: [dir], minSize: 50 * 1024 * 1024, oldAge: .infinity),
            duplicates: DuplicatesScanner(roots: [dir], minSize: 1024 * 1024)
        )
        let result = try await scanner.scan { _, _ in }
        XCTAssertEqual(result.module, .files)
        // 1 large file + 2 duplicate members = 3, with no URL listed twice.
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.items.map(\.url)).count, 3, "URLs must be unique after merge")
        XCTAssertTrue(result.items.contains { $0.kind == .largeFile })
        XCTAssertEqual(result.items.filter { $0.kind == .duplicate }.count, 2)
    }

    func testShellCapturesLargeOutputWithoutDeadlock() {
        // Emit ~1 MB — far past the ~64 KB pipe buffer. The old busy-wait +
        // read-after-exit implementation would deadlock/truncate here.
        let (status, out, _) = Shell.run(
            "/bin/sh",
            ["-c", "for i in $(seq 1 20000); do echo 0123456789012345678901234567890123456789012345678; done"],
            timeout: 30
        )
        XCTAssertEqual(status, 0)
        XCTAssertGreaterThan(out.utf8.count, 900_000)
    }

    func testShellTimeoutIsReported() {
        let (status, _, _) = Shell.run("/bin/sh", ["-c", "sleep 5"], timeout: 0.5)
        XCTAssertEqual(status, Shell.timedOut)
    }

    func testCleanerDryRun() {
        let item = ScanItem(url: tempRoot.appendingPathComponent("ghost"), size: 1000, kind: .cache)
        let report = Cleaner.clean(items: [item], dryRun: true)
        XCTAssertEqual(report.removedCount, 1)
        XCTAssertEqual(report.freedBytes, 1000)
    }
}
