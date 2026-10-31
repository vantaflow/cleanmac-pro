import Foundation
import CleanCore
import CoreGraphics
import ImageIO

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

func smokeImage(_ w: Int, _ h: Int, _ centerX: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                       colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray,
                       locations: nil)!
    let c = CGPoint(x: CGFloat(w) * centerX, y: CGFloat(h) / 2)
    let diag = CGFloat(w * w + h * h).squareRoot()
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: diag,
                           options: [.drawsAfterEndLocation])
    return ctx.makeImage()!
}

func smokeSaveImage(_ image: CGImage, _ url: URL, _ type: String) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
    CGImageDestinationFinalize(dest)
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

        // DeveloperScanner (fixtures only, no external tools)
        let devHome = root.appendingPathComponent("devhome")
        try Smoke.write(4_000, to: devHome.appendingPathComponent("Library/Developer/Xcode/DerivedData/App-x/o.bin"))
        let staleNM = root.appendingPathComponent("devprojects/old/node_modules")
        try Smoke.write(3_000, to: staleNM.appendingPathComponent("dep/i.js"))
        try Smoke.write(5, to: root.appendingPathComponent("devprojects/old/package.json"))
        let longAgo = Date().addingTimeInterval(-200 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: staleNM.path)
        try FileManager.default.setAttributes([.modificationDate: longAgo],
                                              ofItemAtPath: root.appendingPathComponent("devprojects/old/package.json").path)
        let devResult = try await DeveloperScanner(home: devHome,
                                                   projectRoots: [root.appendingPathComponent("devprojects")],
                                                   includeTools: false).scan { _, _ in }
        Smoke.check(devResult.items.contains { $0.group == "Xcode · DerivedData" }, "DeveloperScanner finds DerivedData")
        Smoke.check(devResult.items.contains { $0.group == "node_modules" }, "DeveloperScanner finds stale node_modules")
        Smoke.check(DeveloperScanner.parseSize("1.5GB", base: 1000) == 1_500_000_000, "DeveloperScanner.parseSize parses GB")

        // SimilarPhotosScanner: original, resized JPEG, different image
        let pics = root.appendingPathComponent("Pictures")
        try FileManager.default.createDirectory(at: pics, withIntermediateDirectories: true)
        smokeSaveImage(smokeImage(800, 600, 0.3), pics.appendingPathComponent("orig.png"), "public.png")
        smokeSaveImage(smokeImage(400, 300, 0.3), pics.appendingPathComponent("small.jpg"), "public.jpeg")
        smokeSaveImage(smokeImage(800, 600, 0.7), pics.appendingPathComponent("other.png"), "public.png")
        let photoResult = try await SimilarPhotosScanner(roots: [pics], minFileSize: 0).scan { _, _ in }
        let photoNames = Set(photoResult.items.map { $0.url.lastPathComponent })
        Smoke.check(photoNames == ["orig.png", "small.jpg"], "SimilarPhotosScanner groups resized copy only (got \(photoNames))")
        Smoke.check(photoResult.items.first { $0.kind == .keeper }?.url.lastPathComponent == "orig.png",
                    "SimilarPhotosScanner keeps the highest resolution")

        // Cleaner dry-run
        let ghost = ScanItem(url: root.appendingPathComponent("ghost"), size: 1_000, kind: .cache)
        let report = Cleaner.clean(items: [ghost], dryRun: true)
        Smoke.check(report.removedCount == 1 && report.freedBytes == 1_000, "Cleaner dry-run accounts 1 item, 1000 bytes")

        // Exclusions: prefix match on a path boundary
        let ex = ExclusionList(paths: [cacheDir.appendingPathComponent("c1").path])
        let exFiltered = ex.apply(to: smartResult)
        Smoke.check(exFiltered.count == 1, "Exclusions drop the excluded path only (got \(exFiltered.count))")
        Smoke.check(!ExclusionList.path("/a/bc", isUnder: "/a/b"), "Exclusion /a/b does not match /a/bc")

        // History: simulated trash round-trip + restore
        let fakeTrash = root.appendingPathComponent("FakeTrash/x.dat")
        try Smoke.write(10, to: fakeTrash)
        let origin = root.appendingPathComponent("Restored/x.dat")
        let entry = HistoryEntry(module: "cleanup", itemCount: 1, freedBytes: 10,
                                 records: [TrashRecord(originalPath: origin.path, trashPath: fakeTrash.path)])
        var hist = CleanHistory()
        hist.record(entry)
        try hist.save(to: root)
        Smoke.check(CleanHistory.load(from: root) == hist, "History persists and reloads identically")
        let restored = CleanHistory.restore(entry)
        Smoke.check(restored.restored == [origin.path] && FileManager.default.fileExists(atPath: origin.path),
                    "History restore moves the file back")

        // Scheduled-scan LaunchAgent plist
        let planned = ScheduledScanAgent.plistData(bundleID: "ai.smoke", executablePath: "/x/CleanMacPro",
                                                   schedule: ScanSchedule(frequency: .daily, hour: 8, minute: 15))
        let parsed = planned.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        Smoke.check((parsed?["ProgramArguments"] as? [String])?.last == ScheduledScanAgent.argument,
                    "LaunchAgent plist carries the --scheduled-scan argument")

    } catch {
        Smoke.failures.append("✗ Exception thrown: \(error)")
    }

    // Live checks (network + real /Applications). Opt-in: CI sets CLEANMAC_LIVE=1.
    if ProcessInfo.processInfo.environment["CLEANMAC_LIVE"] == "1" {
        await runLiveSparkleChecks()
        await runLiveInstallCheck()
    }

    do {
        let a = URL(fileURLWithPath: "/a"), b = URL(fileURLWithPath: "/b")
        Smoke.check(PermissionDetector.fullDiskAccess(probes: [a, b]) { $0 == a ? .denied : .readable } == .granted, "FDA granted when a probe is readable")
        Smoke.check(PermissionDetector.fullDiskAccess(probes: [a, b]) { _ in .denied } == .denied, "FDA denied when probes are refused")
        Smoke.check(PermissionDetector.fullDiskAccess(probes: [a]) { _ in .missing } == .notDetermined, "FDA undetermined when no probe exists")
        Smoke.check(PermissionDetector.automation(osStatus: -1743) == .denied, "automation -1743 maps to denied")
        Smoke.check(PermissionDetector.notifications(rawAuthorizationStatus: 2) == .granted, "notifications authorized maps to granted")
        let real = PermissionDetector.fullDiskAccess()
        print("  (real FDA status on this machine: \(real))")
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

/// Runs the Updates scanner on the machine's real apps and checks that every
/// app declaring a Sparkle feed (SUFeedURL) gets a real verdict from its appcast.
/// `CLEANMAC_EXPECT_SPARKLE` names apps that must be found (e.g. "iTerm2").
func runLiveSparkleChecks() async {
    print("\n— Live Sparkle checks —")
    do {
        let result = try await UpdatesScanner().scan { _, _ in }
        let sparkle = result.items.filter { $0.group == "Apps · Direct (Sparkle)" }
        for item in sparkle {
            print("  \(item.title ?? "?") · \(item.detail ?? "") · \(item.severity)")
        }
        let expected = (ProcessInfo.processInfo.environment["CLEANMAC_EXPECT_SPARKLE"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for name in expected where !name.isEmpty {
            let item = sparkle.first { ($0.title ?? "").hasPrefix(name) }
            Smoke.check(item != nil, "\(name) detected as a Sparkle app")
            if let item {
                Smoke.check(item.severity == .good || item.severity == .warn,
                            "\(name) compared against its appcast (got: \(item.detail ?? ""))")
            }
        }
        // `CLEANMAC_EXPECT_UPDATE` names apps made outdated on purpose: they must be flagged.
        let outdated = (ProcessInfo.processInfo.environment["CLEANMAC_EXPECT_UPDATE"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for name in outdated where !name.isEmpty {
            let item = sparkle.first { ($0.title ?? "").hasPrefix(name) }
            Smoke.check(item?.severity == .warn && (item?.title ?? "").contains("→"),
                        "\(name) flagged as outdated (got: \(item?.title ?? "absent"))")
        }
    } catch {
        Smoke.failures.append("✗ UpdatesScanner threw: \(error)")
    }
}

/// `CLEANMAC_INSTALL_UPDATE` names an outdated Sparkle app to really update in place;
/// afterwards the installed bundle must carry the appcast version.
func runLiveInstallCheck() async {
    let name = (ProcessInfo.processInfo.environment["CLEANMAC_INSTALL_UPDATE"] ?? "")
        .trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }
    print("\n— Live install check (\(name)) —")
    do {
        let result = try await UpdatesScanner().scan { _, _ in }
        guard let item = result.items.first(where: {
            $0.group == "Apps · Direct (Sparkle)" && ($0.title ?? "").hasPrefix(name)
        }), let release = item.sparkleRelease else {
            Smoke.failures.append("✗ \(name): no outdated Sparkle item to install")
            return
        }
        let outcome = await SparkleInstaller.install(appURL: item.url, release: release) { print("  … \($0)") }
        print("  outcome: \(outcome)")
        Smoke.check({ if case .installed = outcome { return true } else { return false } }(),
                    "\(name) installed in place (\(outcome.message))")
        let plist = NSDictionary(contentsOfFile: item.url.appendingPathComponent("Contents/Info.plist").path)
        let build = plist?["CFBundleVersion"] as? String
        let short = plist?["CFBundleShortVersionString"] as? String
        print("  installed now: v\(short ?? "?") (build \(build ?? "?")), appcast: v\(release.shortVersion ?? "?") (build \(release.build ?? "?"))")
        Smoke.check(build == release.build || short == release.shortVersion,
                    "\(item.url.path) has the appcast version")
        let rescan = try await UpdatesScanner().scan { _, _ in }
        let again = rescan.items.first { $0.group == "Apps · Direct (Sparkle)" && ($0.title ?? "").hasPrefix(name) }
        Smoke.check(again?.severity == .good, "\(name) reported up to date after install (got: \(again?.detail ?? "absent"))")
    } catch {
        Smoke.failures.append("✗ install check threw: \(error)")
    }
}

/// `CleanMacProSmoke --probe`: runs the real scanners on this Mac (read-only) and
/// prints what each would propose, grouped, with sizes. Nothing is cleaned.
func runProbe() async {
    let scanners: [any FileScanner] = [CleanupScanner(), FilesScanner(), PrivacyScanner(),
                                       DeveloperScanner(), UpdatesScanner(), AppUninstaller()]
    for s in scanners {
        let t0 = Date()
        guard let r = try? await s.scan(progress: { _, _ in }) else { print("\(s.module): scan threw"); continue }
        print("\n== \(s.module) · \(r.items.count) items · \(ByteFormatter.string(r.totalSize)) · \(String(format: "%.1f", Date().timeIntervalSince(t0)))s")
        let groups = Dictionary(grouping: r.items, by: { $0.group ?? "-" })
        for (g, items) in groups.sorted(by: { $0.value.reduce(0) { $0 + $1.size } > $1.value.reduce(0) { $0 + $1.size } }).prefix(12) {
            print("   \(g): \(items.count) · \(ByteFormatter.string(items.reduce(0) { $0 + $1.size })) · ex: \(items.first?.name ?? "")")
        }
    }
    exit(0)
}

if CommandLine.arguments.contains("--probe") { await runProbe() }
await runSmoke()
