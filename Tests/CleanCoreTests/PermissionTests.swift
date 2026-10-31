import XCTest
@testable import CleanCore

final class PermissionTests: XCTestCase {
    private let a = URL(fileURLWithPath: "/a"), b = URL(fileURLWithPath: "/b")

    func testGrantedWhenAnyProbeReadable() {
        let s = PermissionDetector.fullDiskAccess(probes: [a, b]) { $0 == self.a ? .denied : .readable }
        XCTAssertEqual(s, .granted)
    }
    func testDeniedWhenExistingProbeRefused() {
        let s = PermissionDetector.fullDiskAccess(probes: [a, b]) { $0 == self.a ? .missing : .denied }
        XCTAssertEqual(s, .denied)
    }
    func testUndeterminedWhenNothingExists() {
        XCTAssertEqual(PermissionDetector.fullDiskAccess(probes: [a, b]) { _ in .missing }, .notDetermined)
        XCTAssertEqual(PermissionDetector.fullDiskAccess(probes: []) { _ in .readable }, .notDetermined)
    }
    func testRealReadOutcomes() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("perm-\(UUID().uuidString)")
        try "x".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertEqual(PermissionDetector.systemRead(tmp), .readable)
        XCTAssertEqual(PermissionDetector.systemRead(tmp.appendingPathExtension("nope")), .missing)
        XCTAssertEqual(PermissionDetector.systemRead(URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)), .readable)
    }
    func testNotificationMapping() {
        XCTAssertEqual(PermissionDetector.notifications(rawAuthorizationStatus: 0), .notDetermined)
        XCTAssertEqual(PermissionDetector.notifications(rawAuthorizationStatus: 1), .denied)
        XCTAssertEqual(PermissionDetector.notifications(rawAuthorizationStatus: 2), .granted)
        XCTAssertEqual(PermissionDetector.notifications(rawAuthorizationStatus: 3), .granted)
    }
    func testAutomationMapping() {
        XCTAssertEqual(PermissionDetector.automation(osStatus: 0), .granted)
        XCTAssertEqual(PermissionDetector.automation(osStatus: -1743), .denied)
        XCTAssertEqual(PermissionDetector.automation(osStatus: -1744), .notDetermined)
        XCTAssertEqual(PermissionDetector.automation(osStatus: -600), .notDetermined)
    }
    func testSettingsURLsAndModules() {
        for k in PermissionKind.allCases { XCTAssertTrue(k.settingsURL.absoluteString.hasPrefix("x-apple.systempreferences:")) }
        XCTAssertTrue(PermissionNeeds.needsFullDiskAccess(.privacy))
        XCTAssertFalse(PermissionNeeds.needsFullDiskAccess(.updates))
    }
}
