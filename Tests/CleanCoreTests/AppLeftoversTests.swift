import XCTest
@testable import CleanCore

final class AppLeftoversTests: XCTestCase {
    var root: URL!
    var apps: URL!
    var lib: URL!
    var trash: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("leftovers-\(UUID().uuidString)")
        apps = root.appendingPathComponent("Applications")
        lib = root.appendingPathComponent("Library")
        trash = root.appendingPathComponent(".Trash")
        for d in [apps!, lib!, trash!] { try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    @discardableResult
    func makeApp(_ name: String, id: String, in dir: URL? = nil, nested: [String] = []) throws -> URL {
        let app = (dir ?? apps).appendingPathComponent("\(name).app")
        let c = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        try plist(["CFBundleIdentifier": id], at: c.appendingPathComponent("Info.plist"))
        for n in nested {
            let d = c.appendingPathComponent("PlugIns/\(n).appex/Contents")
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            try plist(["CFBundleIdentifier": n], at: d.appendingPathComponent("Info.plist"))
        }
        return app
    }
    func plist(_ d: [String: Any], at url: URL) throws {
        try PropertyListSerialization.data(fromPropertyList: d, format: .xml, options: 0).write(to: url)
    }
    func file(_ rel: String, bytes: Int = 2000) throws {
        let u = lib.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: u)
    }
    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: lib.appendingPathComponent(rel).path) }

    func seedFoo() throws {
        try file("Application Support/Foo/data.bin")
        try file("Caches/com.foo.app/c.bin")
        try file("Preferences/com.foo.app.plist")
        try file("Saved Application State/com.foo.app.savedState/w.data")
        try file("Containers/com.foo.app/x")
        try file("Group Containers/ABCDE12345.com.foo.app/x")
        try file("Group Containers/group.com.foo.app/x")
        try file("HTTPStorages/com.foo.app/x")
        try file("WebKit/com.foo.app/x")
        try file("Logs/Foo/l.log")
        try file("Cookies/com.foo.app.binarycookies")
        try file("Caches/com.foo.app.helper/x")
    }

    func testFindsAllLocations() throws {
        try seedFoo()
        let items = AppLeftovers(library: lib).find(bundleID: "com.foo.app", name: "Foo")
        XCTAssertEqual(items.count, 12)
        XCTAssertTrue(items.allSatisfy { $0.size > 0 }, "plist files must have a size too")
    }

    func testNoPartialNameOrSubstringMatch() throws {
        try file("Application Support/FooBar/x")
        try file("Application Support/Foo Pro/x")
        try file("Caches/com.foo.application/x")     // shares a string prefix, not a component
        try file("Preferences/com.foo.app2.plist")
        try file("Caches/notcom.foo.app/x")
        let items = AppLeftovers(library: lib).find(bundleID: "com.foo.app", name: "Foo")
        XCTAssertTrue(items.isEmpty, "\(items.map(\.name))")
    }

    func testSharedFolderOfAnotherInstalledAppIsNeverClaimed() throws {
        try file("Caches/com.foo.app.sibling/x")
        try file("Application Support/Foo/x")
        let l = AppLeftovers(library: lib)
        let items = l.find(bundleID: "com.foo.app", name: "Foo",
                           otherInstalledIDs: ["com.foo.app.sibling"], otherInstalledNames: ["foo"])
        XCTAssertTrue(items.isEmpty)
    }

    func testLiveLaunchAgentIsKept() throws {
        try plist(["Label": "com.foo.app.agent", "ProgramArguments": ["/bin/ls"]],
                  at: { try! FileManager.default.createDirectory(at: lib.appendingPathComponent("LaunchAgents"), withIntermediateDirectories: true); return lib.appendingPathComponent("LaunchAgents/com.foo.app.agent.plist") }())
        XCTAssertTrue(AppLeftovers(library: lib).find(bundleID: "com.foo.app", name: "Foo").isEmpty)
        try plist(["Label": "com.foo.app.gone", "ProgramArguments": ["/nonexistent/foo"]],
                  at: lib.appendingPathComponent("LaunchAgents/com.foo.app.gone.plist"))
        XCTAssertEqual(AppLeftovers(library: lib).find(bundleID: "com.foo.app", name: "Foo").count, 1)
    }

    func testIndexReadsBundleIDsAndNestedHelpers() throws {
        try makeApp("Foo", id: "com.foo.app", nested: ["com.foo.app.share"])
        try makeApp("Tool", id: "org.tool.t", in: apps.appendingPathComponent("Sub", isDirectory: true))
        let idx = AppIndex.build(roots: [apps])
        XCTAssertEqual(Set(idx.apps.map(\.bundleID)), ["com.foo.app", "org.tool.t"])
        XCTAssertTrue(idx.knownIDs().contains("com.foo.app.share"))
        XCTAssertTrue(idx.isInstalled(bundleID: "COM.FOO.APP"))
    }

    func testOrphansNoFalsePositives() throws {
        try makeApp("Foo", id: "com.foo.app")
        try makeApp("Word", id: "com.microsoft.Word")
        let idx = AppIndex.build(roots: [apps])
        try file("Caches/com.foo.app/x")                 // installed
        try file("Caches/com.foo.app.helper/x")          // helper prefix of installed
        try file("Caches/com.foo/x")                     // parent namespace of installed
        try file("Caches/com.apple.Safari/x")            // system
        try file("Caches/com.microsoft.Excel/x")         // vendor shared with installed Word
        try file("Caches/Homebrew/x")                    // not a bundle id
        try file("Caches/org.swift.swiftpm/x")           // developer tooling
        try file("Caches/file.sync.thing/x")             // unknown TLD
        try file("Caches/com.gone.OldApp/x", bytes: 5000)
        try file("Preferences/com.gone.OldApp.plist")
        try file("Group Containers/ABCDE12345.com.gone.OldApp/x")
        try file("Preferences/ByHost/com.gone.OldApp.\(UUID().uuidString).plist")
        try file("Caches/org.other.Dead/x")
        let orphans = AppLeftovers(library: lib).orphans(index: idx)
        XCTAssertEqual(Set(orphans.map(\.bundleID)), ["com.gone.OldApp", "org.other.Dead"])
        let gone = try XCTUnwrap(orphans.first { $0.bundleID == "com.gone.OldApp" })
        XCTAssertEqual(gone.items.count, 4)
        XCTAssertEqual(orphans.first?.bundleID, "com.gone.OldApp", "largest first")
    }

    func testOrphanInstalledElsewhereViaExtraIDs() throws {
        try file("Caches/com.gone.OldApp/x")
        var idx = AppIndex.build(roots: [apps])
        XCTAssertEqual(AppLeftovers(library: lib).orphans(index: idx).count, 1)
        idx.extraIDs.insert("com.gone.oldapp")
        XCTAssertTrue(AppLeftovers(library: lib).orphans(index: idx).isEmpty)
    }

    // MARK: Detector

    func detector() -> AppRemovalDetector { AppRemovalDetector(roots: [apps], trash: trash) }

    func testDetectsRemovedAppAndReportsLeftovers() throws {
        let app = try makeApp("Foo", id: "com.foo.app")
        try seedFoo()
        var d = detector()
        XCTAssertTrue(d.refresh().isEmpty)
        try FileManager.default.removeItem(at: app)
        let removed = d.refresh()
        XCTAssertEqual(removed.map(\.bundleID), ["com.foo.app"])
        let ev = d.events(for: removed, leftovers: AppLeftovers(library: lib),
                          installed: AppIndex.build(roots: [apps]), exclusions: ExclusionList())
        XCTAssertEqual(ev.count, 1)
        XCTAssertEqual(ev[0].items.count, 12)
        XCTAssertEqual(ev[0].appName, "Foo")
        XCTAssertTrue(d.refresh().isEmpty, "reported once")
    }

    func testAppRemovedWhileNotRunningIsReportedAtNextLaunch() throws {
        let state = root.appendingPathComponent("state/app-index.json")
        let app = try makeApp("Foo", id: "com.foo.app")
        try makeApp("Bar", id: "com.bar.app")
        let first = AppRemovalDetector(roots: [apps], trash: trash, stateFile: state)
        XCTAssertTrue(first.removedSinceLastRun.isEmpty, "first launch has nothing to compare with")
        // CleanMac Pro is closed; the user deletes Foo with rm.
        try FileManager.default.removeItem(at: app)
        let second = AppRemovalDetector(roots: [apps], trash: trash, stateFile: state)
        XCTAssertEqual(second.removedSinceLastRun.map(\.bundleID), ["com.foo.app"])
        let third = AppRemovalDetector(roots: [apps], trash: trash, stateFile: state)
        XCTAssertTrue(third.removedSinceLastRun.isEmpty, "reported once")
    }

    func testAppMovedToTrashIsDetectedViaIndex() throws {
        let app = try makeApp("Foo", id: "com.foo.app")
        try file("Caches/com.foo.app/x")
        var d = detector()
        try FileManager.default.moveItem(at: app, to: trash.appendingPathComponent("Foo.app"))
        let removed = d.refresh()
        XCTAssertEqual(removed.map(\.bundleID), ["com.foo.app"], "one event, not one per index + trash")
    }

    func testUnindexedAppTrashedIsReadFromTrash() throws {
        var d = detector()
        let other = root.appendingPathComponent("Downloads")
        let app = try makeApp("Bar", id: "com.bar.app", in: other)
        try file("Caches/com.bar.app/x")
        try FileManager.default.moveItem(at: app, to: trash.appendingPathComponent("Bar.app"))
        XCTAssertEqual(d.refresh().map(\.bundleID), ["com.bar.app"])
    }

    func testPreExistingTrashIsIgnored() throws {
        let other = root.appendingPathComponent("Downloads")
        let app = try makeApp("Bar", id: "com.bar.app", in: other)
        try FileManager.default.moveItem(at: app, to: trash.appendingPathComponent("Bar.app"))
        var d = detector()
        XCTAssertTrue(d.refresh().isEmpty)
    }

    func testMovedOrReplacedAppIsNotARemoval() throws {
        let app = try makeApp("Foo", id: "com.foo.app")
        var d = detector()
        try FileManager.default.moveItem(at: app, to: apps.appendingPathComponent("Foo 2.app"))
        XCTAssertTrue(d.refresh().isEmpty, "same bundle id still installed")
    }

    func testTrashedAppStillInstalledElsewhereIsNotARemoval() throws {
        try makeApp("Foo", id: "com.foo.app")
        var d = detector()
        let other = root.appendingPathComponent("Downloads")
        let dup = try makeApp("Foo", id: "com.foo.app", in: other)
        try FileManager.default.moveItem(at: dup, to: trash.appendingPathComponent("Foo.app"))
        XCTAssertTrue(d.refresh().isEmpty)
    }

    func testNoPromptWhenNothingLeftOrExcluded() throws {
        let app = try makeApp("Foo", id: "com.foo.app")
        var d = detector()
        try FileManager.default.removeItem(at: app)
        let removed = d.refresh()
        let l = AppLeftovers(library: lib)
        XCTAssertTrue(d.events(for: removed, leftovers: l, installed: AppIndex(), exclusions: ExclusionList()).isEmpty)
        try file("Caches/com.foo.app/x")
        XCTAssertEqual(d.events(for: removed, leftovers: l, installed: AppIndex(), exclusions: ExclusionList()).count, 1)
        XCTAssertTrue(d.events(for: removed, leftovers: l, installed: AppIndex(),
                               exclusions: ExclusionList(appIDs: ["com.foo.app"])).isEmpty)
        let byPath = ExclusionList(paths: [lib.appendingPathComponent("Caches").path])
        XCTAssertTrue(d.events(for: removed, leftovers: l, installed: AppIndex(), exclusions: byPath).isEmpty)
    }

    func testWatcherSeesRealFSEvents() throws {
        let app = try makeApp("Foo", id: "com.foo.app")
        try file("Caches/com.foo.app/x")
        let got = expectation(description: "removal")
        let w = AppRemovalWatcher(roots: [apps], trash: trash, library: lib, settleDelay: 0.3,
                                  exclusions: { ExclusionList() }) { ev in
            XCTAssertEqual(ev.bundleID, "com.foo.app"); got.fulfill()
        }
        w.start()
        Thread.sleep(forTimeInterval: 1.0)
        try FileManager.default.moveItem(at: app, to: trash.appendingPathComponent("Foo.app"))
        wait(for: [got], timeout: 15)
        w.stop()
    }

    func testPermanentHistoryEntry() {
        var h = CleanHistory()
        XCTAssertNil(h.recordPermanent(module: "uninstaller", report: CleanReport(removedCount: 0, freedBytes: 0, failedItems: [])))
        let e = h.recordPermanent(module: "uninstaller", report: CleanReport(removedCount: 3, freedBytes: 99, failedItems: []))
        XCTAssertEqual(e?.records.count, 0)
        XCTAssertEqual(h.entries.count, 1)
    }
}
