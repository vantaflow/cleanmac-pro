import XCTest
import CryptoKit
@testable import CleanCore

final class SparkleInstallerTests: XCTestCase {

    private func tmp() throws -> URL {
        let u = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sparkle-installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: u) }
        return u
    }

    private func mkdir(_ u: URL) throws {
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    }

    func testFindAppTopLevelPrefersName() throws {
        let d = try tmp()
        try mkdir(d.appendingPathComponent("Other.app"))
        try mkdir(d.appendingPathComponent("Rectangle.app"))
        XCTAssertEqual(SparkleInstaller.findApp(in: d, preferredName: "Rectangle")?.lastPathComponent, "Rectangle.app")
        XCTAssertEqual(SparkleInstaller.findApp(in: d)?.lastPathComponent, "Other.app")
    }

    func testFindAppOneLevelDeep() throws {
        let d = try tmp()
        try mkdir(d.appendingPathComponent("Folder/Thing.app"))
        XCTAssertEqual(SparkleInstaller.findApp(in: d)?.lastPathComponent, "Thing.app")
    }

    func testFindAppNone() throws {
        let d = try tmp()
        try mkdir(d.appendingPathComponent("Docs"))
        XCTAssertNil(SparkleInstaller.findApp(in: d))
    }

    func testCheckCandidate() {
        let old = SparkleBundleInfo(bundleID: "com.x", shortVersion: "1.0", build: "10")
        XCTAssertNil(SparkleInstaller.checkCandidate(
            installed: old, candidate: .init(bundleID: "com.x", shortVersion: "1.1", build: "11")))
        XCTAssertNotNil(SparkleInstaller.checkCandidate(
            installed: old, candidate: .init(bundleID: "com.y", shortVersion: "1.1", build: "11")))
        XCTAssertNotNil(SparkleInstaller.checkCandidate(
            installed: old, candidate: .init(bundleID: "com.x", shortVersion: "1.0", build: "10")))
        XCTAssertNotNil(SparkleInstaller.checkCandidate(
            installed: old, candidate: .init(bundleID: "com.x", shortVersion: "0.9", build: "9")))
        // Without builds, marketing versions decide.
        XCTAssertNil(SparkleInstaller.checkCandidate(
            installed: .init(bundleID: "com.x", shortVersion: "1.0", build: ""),
            candidate: .init(bundleID: "com.x", shortVersion: "1.2", build: "")))
    }

    func testTeamIdentifierParsing() {
        XCTAssertEqual(SparkleInstaller.teamIdentifier(fromCodesignOutput: "Identifier=a\nTeamIdentifier=ABCDE12345\n"), "ABCDE12345")
        XCTAssertNil(SparkleInstaller.teamIdentifier(fromCodesignOutput: "TeamIdentifier=not set\n"))
        XCTAssertNil(SparkleInstaller.teamIdentifier(fromCodesignOutput: "Identifier=a\n"))
    }

    func testEdDSAVerification() {
        let key = Curve25519.Signing.PrivateKey()
        let data = Data("archive bytes".utf8)
        let sig = try! key.signature(for: data).base64EncodedString()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        XCTAssertTrue(SparkleInstaller.verifyEdDSA(data: data, signature: sig, publicKey: pub))
        XCTAssertFalse(SparkleInstaller.verifyEdDSA(data: Data("tampered".utf8), signature: sig, publicKey: pub))
        let other = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        XCTAssertFalse(SparkleInstaller.verifyEdDSA(data: data, signature: sig, publicKey: other))
        XCTAssertFalse(SparkleInstaller.verifyEdDSA(data: data, signature: "not base64!", publicKey: pub))
    }

    func testArchiveKind() {
        func kind(_ n: String, _ head: [UInt8] = []) -> SparkleInstaller.ArchiveKind? {
            SparkleInstaller.archiveKind(url: URL(string: "https://e.com/\(n)")!, fileHead: Data(head))
        }
        XCTAssertEqual(kind("a.zip"), .zip)
        XCTAssertEqual(kind("a.dmg"), .dmg)
        XCTAssertEqual(kind("a.pkg"), .pkg)
        XCTAssertEqual(kind("download", [0x50, 0x4B, 3, 4]), .zip)
        XCTAssertNil(kind("download", [1, 2, 3, 4]))
    }

    func testAppcastParsesEdSignatureAndLength() {
        let xml = Data("""
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><sparkle:version>5</sparkle:version><sparkle:shortVersionString>1.5</sparkle:shortVersionString>
        <enclosure url="https://e.com/a.zip" length="1234" type="application/octet-stream" sparkle:edSignature="c2ln"/></item>
        </channel></rss>
        """.utf8)
        let r = SparkleAppcast.latest(from: xml, osVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0))
        XCTAssertEqual(r?.edSignature, "c2ln")
        XCTAssertEqual(r?.length, 1234)
    }
}
