import Foundation
import CleanCore

// Standalone smoke-test runner. Runs every scanner against fixture trees
// in $TMPDIR. Exits non-zero on failure. Useful when XCTest isn't available
// (Command Line Tools only).

struct Smoke {
    static var failures: [String] = []

    static func check(_ condition: Bool, _ message: @autoclosure () -> String) {
        if !condition {
            failures.append("✗ \(message())")
        } else {
            print("✓ \(message())")
        }
    }

    static func tmpDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cleanmac-smoke-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func write(_ bytes: Int, to url: URL, byte: UInt8 = 0xAB) throws {
        let parent = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try Data(repeating: byte, count: bytes).write(to: url)
    }
}

func runSmoke() async {
    do {
        // ByteFormatter
        Smoke.check(!ByteFormatter.string(1_500_000).isEmpty, "ByteFormatter produces output")

        // FS.enumerate + size
        let root = try Smoke.tmpDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try Smoke.write(100, to: root.appendingPathComponent("a.txt"))
        try Smoke.write(200, to: root.appendingPathComponent("sub/b.txt"))
        let files = Array(FS.enumerate(root))
        Smoke.check(files.count == 2, "FS.enumerate finds 2 files (got \(files.count))")
        let totalSize = files.reduce(Int64(0)) { $0 + FS.size(of: $1) }
        Smoke.check(totalSize >= 300, "FS.size sums to ≥300 (got \(totalSize))")

        // CleanupScanner with overrides
        let cacheDir = root.appendingPathComponent("Caches")
        try Smoke.write(1_000, to: cacheDir.appendingPathComponent("c1"))
        try Smoke.write(2_000, to: cacheDir.appendingPathComponent("c2"))
        let smart = CleanupScanner(rootOverrides: [cacheDir])
        let smartResult = try await smart.scan { _, _ in }
        Smoke.check(smartResult.count == 2, "CleanupScanner finds 2 items (got \(smartResult.count))")

        // LargeFilesScanner
        let dl = root.appendingPathComponent("Downloads")
        try Smoke.write(100, to: dl.appendingPathComponent("small.dat"))
        try Smoke.write(60 * 1024 * 1024, to: dl.appendingPathComponent("huge.dat"))
        let large = LargeFilesScanner(roots: [dl], minSize: 50 * 1024 * 1024, oldAge: .infinity)
        let largeResult = try await large.scan { _, _ in }
        Smoke.check(largeResult.count == 1, "LargeFilesScanner finds 1 large file (got \(largeResult.count))")
        Smoke.check(largeResult.items.first?.kind == .largeFile, "Item kind is .largeFile")

        // DuplicatesScanner
        let docs = root.appendingPathComponent("Docs")
        let payload = Data(repeating: 0x42, count: 2 * 1024 * 1024)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try payload.write(to: docs.appendingPathComponent("copy1.bin"))
        try payload.write(to: docs.appendingPathComponent("copy2.bin"))
        try Data(repeating: 0x01, count: 2 * 1024 * 1024).write(to: docs.appendingPathComponent("unique.bin"))
        let dup = DuplicatesScanner(roots: [docs], minSize: 1024 * 1024)
        let dupResult = try await dup.scan { _, _ in }
        Smoke.check(dupResult.count == 2, "DuplicatesScanner finds 2 dup members (got \(dupResult.count))")

        // Cleaner dry-run
        let ghost = ScanItem(url: root.appendingPathComponent("ghost"), size: 1_000, kind: .cache)
        let report = Cleaner.clean(items: [ghost], dryRun: true)
        Smoke.check(report.removedCount == 1 && report.freedBytes == 1_000, "Cleaner dry-run accounts 1 item, 1000 bytes")

    } catch {
        Smoke.failures.append("✗ Exception thrown: \(error)")
    }

    print("\n— Smoke summary —")
    if Smoke.failures.isEmpty {
        print("All checks passed ✓")
        exit(0)
    } else {
        for f in Smoke.failures { print(f) }
        print("\n\(Smoke.failures.count) failure(s)")
        exit(1)
    }
}

await runSmoke()
