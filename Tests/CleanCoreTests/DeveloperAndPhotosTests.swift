import XCTest
import CoreGraphics
import ImageIO
@testable import CleanCore

final class DeveloperAndPhotosTests: XCTestCase {
    var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cleanmac-devphotos-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func write(_ bytes: Int, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
    }

    private func setDate(_ url: URL, daysAgo: Double) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-daysAgo * 86_400)], ofItemAtPath: url.path)
    }

    // MARK: Developer

    func testDeveloperScannerFindsFixtures() async throws {
        let home = tempRoot.appendingPathComponent("home")
        let xcode = home.appendingPathComponent("Library/Developer/Xcode")
        try write(5_000, to: xcode.appendingPathComponent("DerivedData/MyApp-abc/Build/o.bin"))
        try write(3_000, to: xcode.appendingPathComponent("iOS DeviceSupport/17.0 (21A)/sym.bin"))
        let oldArchive = xcode.appendingPathComponent("Archives/2024-01-01/Old.xcarchive")
        let newArchive = xcode.appendingPathComponent("Archives/2024-02-01/New.xcarchive")
        try write(2_000, to: oldArchive.appendingPathComponent("a.bin"))
        try write(2_000, to: newArchive.appendingPathComponent("a.bin"))
        try setDate(oldArchive, daysAgo: 200)
        try write(1_000, to: home.appendingPathComponent("Library/Developer/CoreSimulator/Caches/c.bin"))
        try write(4_000, to: home.appendingPathComponent("Library/Caches/org.swift.swiftpm/x.bin"))
        try write(4_000, to: home.appendingPathComponent(".gradle/caches/y.bin"))

        let projects = home.appendingPathComponent("Projects")
        // old project (package.json + node_modules both old)
        let oldProj = projects.appendingPathComponent("old")
        try write(10, to: oldProj.appendingPathComponent("package.json"))
        try write(6_000, to: oldProj.appendingPathComponent("node_modules/dep/index.js"))
        try setDate(oldProj.appendingPathComponent("package.json"), daysAgo: 300)
        try setDate(oldProj.appendingPathComponent("node_modules"), daysAgo: 300)
        // fresh project
        let freshProj = projects.appendingPathComponent("fresh")
        try write(10, to: freshProj.appendingPathComponent("package.json"))
        try write(6_000, to: freshProj.appendingPathComponent("node_modules/dep/index.js"))
        // orphan (no package.json), fresh
        let orphan = projects.appendingPathComponent("orphan")
        try write(6_000, to: orphan.appendingPathComponent("node_modules/dep/index.js"))

        let scanner = DeveloperScanner(home: home, projectRoots: [projects], includeTools: false)
        let result = try await scanner.scan { _, _ in }
        func items(_ group: String) -> [ScanItem] { result.items.filter { $0.group == group } }

        XCTAssertEqual(items("Xcode · DerivedData").count, 1)
        XCTAssertEqual(items("Xcode · DeviceSupport").count, 1)
        let archives = items(L("Xcode · Archives anciennes"))
        XCTAssertEqual(archives.count, 1)
        XCTAssertEqual(archives.first?.url.lastPathComponent, "Old.xcarchive")
        XCTAssertEqual(items(L("Xcode · Simulateurs")).count, 1)
        XCTAssertEqual(items("Caches de paquets").count, 2)

        let nm = items("node_modules").map { $0.url.deletingLastPathComponent().lastPathComponent }.sorted()
        XCTAssertEqual(nm, ["old", "orphan"])
        XCTAssertTrue(result.items.allSatisfy { $0.size > 0 })
        XCTAssertEqual(result.module, .developer)
    }

    func testDeveloperScannerEmptyHome() async throws {
        let scanner = DeveloperScanner(home: tempRoot, projectRoots: [tempRoot.appendingPathComponent("none")],
                                       includeTools: false)
        let result = try await scanner.scan { _, _ in }
        XCTAssertTrue(result.items.isEmpty)
    }

    func testToolOutputParsers() {
        XCTAssertEqual(DeveloperScanner.parseSize("1.5GB", base: 1000), 1_500_000_000)
        XCTAssertEqual(DeveloperScanner.parseSize("312 MB (4%)", base: 1000), 312_000_000)
        XCTAssertEqual(DeveloperScanner.parseSize("0B", base: 1000), 0)
        XCTAssertNil(DeveloperScanner.parseSize("rien", base: 1000))
        let brew = "Removing: x\n==> This operation would free approximately 2GB of disk space.\n"
        XCTAssertEqual(DeveloperScanner.parseBrewCleanup(brew), 2 * 1024 * 1024 * 1024)
        XCTAssertNil(DeveloperScanner.parseBrewCleanup("nothing"))
        XCTAssertEqual(DeveloperScanner.parseDockerReclaimable("Images|1GB (50%)\nContainers|500MB (100%)\n"),
                       1_500_000_000)
        let json = """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-15-0":[
          {"name":"iPhone 12","isAvailable":false,"dataPath":"/tmp/x"}],
         "com.apple.CoreSimulator.SimRuntime.iOS-17-0":[
          {"name":"iPhone 15","isAvailable":true}]}}
        """.data(using: .utf8)!
        let sims = DeveloperScanner.parseUnavailableSimulators(json)
        XCTAssertEqual(sims.map(\.name), ["iPhone 12"])
    }

    // MARK: Similar photos

    /// Radial gradient peaking at `centerX` (fraction of width): no flat areas, so the
    /// dHash is stable under resizing and JPEG compression.
    static func makeImage(width: Int, height: Int, centerX: CGFloat) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                                  colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 0, alpha: 1)] as CFArray,
                                  locations: nil)!
        let c = CGPoint(x: CGFloat(width) * centerX, y: CGFloat(height) / 2)
        let diag = CGFloat(width * width + height * height).squareRoot()
        ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: diag,
                               options: [.drawsAfterEndLocation])
        return ctx.makeImage()!
    }

    static func save(_ image: CGImage, to url: URL, type: String, quality: Double = 0.7) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        CGImageDestinationFinalize(dest)
    }

    func testSimilarPhotosGroupsResizedVersionNotDifferentImage() async throws {
        let pics = tempRoot.appendingPathComponent("Pictures")
        let big = pics.appendingPathComponent("original.png")
        let small = pics.appendingPathComponent("small.jpg")
        let other = pics.appendingPathComponent("other.png")
        Self.save(Self.makeImage(width: 800, height: 600, centerX: 0.3), to: big, type: "public.png")
        Self.save(Self.makeImage(width: 400, height: 300, centerX: 0.3), to: small, type: "public.jpeg", quality: 0.6)
        Self.save(Self.makeImage(width: 800, height: 600, centerX: 0.7), to: other, type: "public.png")

        let hBig = try XCTUnwrap(SimilarPhotosScanner.analyze(url: big)).hash
        let hSmall = try XCTUnwrap(SimilarPhotosScanner.analyze(url: small)).hash
        let hOther = try XCTUnwrap(SimilarPhotosScanner.analyze(url: other)).hash
        XCTAssertLessThanOrEqual((hBig ^ hSmall).nonzeroBitCount, 6)
        XCTAssertGreaterThan((hBig ^ hOther).nonzeroBitCount, 6)

        let scanner = SimilarPhotosScanner(roots: [pics], threshold: 6, minFileSize: 0)
        let result = try await scanner.scan { _, _ in }
        XCTAssertEqual(result.items.count, 2)
        let names = Set(result.items.map { $0.url.lastPathComponent })
        XCTAssertEqual(names, ["original.png", "small.jpg"])
        XCTAssertEqual(result.items.first { $0.kind == .keeper }?.url.lastPathComponent, "original.png")
        XCTAssertEqual(result.items.first { $0.kind == .duplicate }?.url.lastPathComponent, "small.jpg")
        XCTAssertEqual(Set(result.items.compactMap(\.group)).count, 1)
    }

    func testBKTreeMatchesBruteForce() {
        var tree = BKTree()
        var hashes: [UInt64] = []
        var x: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<300 {
            x = x &* 6364136223846793005 &+ 1442695040888963407
            let h = (i % 5 == 0 && !hashes.isEmpty) ? hashes[i / 2] ^ (UInt64(1) << UInt64(i % 64)) : x
            hashes.append(h)
            tree.insert(hash: h, index: i)
        }
        for q in [0, 7, 150, 299] {
            let expected = Set(hashes.indices.filter { (hashes[$0] ^ hashes[q]).nonzeroBitCount <= 6 })
            XCTAssertEqual(Set(tree.search(hash: hashes[q], radius: 6)), expected)
        }
    }
}
