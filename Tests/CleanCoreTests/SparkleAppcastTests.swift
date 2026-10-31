import XCTest
@testable import CleanCore

final class SparkleAppcastTests: XCTestCase {

    private let sonoma = OperatingSystemVersion(majorVersion: 14, minorVersion: 5, patchVersion: 0)

    private func feed(_ items: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel><title>Test</title>\(items)</channel>
        </rss>
        """.utf8)
    }

    func testPicksHighestBuildFromElements() {
        let data = feed("""
        <item><sparkle:version>120</sparkle:version><sparkle:shortVersionString>1.2</sparkle:shortVersionString>
          <enclosure url="https://example.com/1.2.zip"/></item>
        <item><sparkle:version>140</sparkle:version><sparkle:shortVersionString>1.4</sparkle:shortVersionString>
          <enclosure url="https://example.com/1.4.zip"/></item>
        <item><sparkle:version>130</sparkle:version><sparkle:shortVersionString>1.3</sparkle:shortVersionString></item>
        """)
        let latest = SparkleAppcast.latest(from: data, osVersion: sonoma)
        XCTAssertEqual(latest?.build, "140")
        XCTAssertEqual(latest?.shortVersion, "1.4")
        XCTAssertEqual(latest?.downloadURL?.absoluteString, "https://example.com/1.4.zip")
    }

    func testReadsVersionsFromEnclosureAttributes() {
        let data = feed("""
        <item><enclosure url="https://example.com/a.dmg" sparkle:version="2051" sparkle:shortVersionString="5.2.1"/></item>
        """)
        let latest = SparkleAppcast.latest(from: data, osVersion: sonoma)
        XCTAssertEqual(latest?.build, "2051")
        XCTAssertEqual(latest?.displayVersion, "5.2.1")
    }

    func testIgnoresBetaChannelAndTooNewSystem() {
        let data = feed("""
        <item><sparkle:version>100</sparkle:version><sparkle:shortVersionString>1.0</sparkle:shortVersionString></item>
        <item><sparkle:version>200</sparkle:version><sparkle:channel>beta</sparkle:channel></item>
        <item><sparkle:version>300</sparkle:version><sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion></item>
        """)
        let latest = SparkleAppcast.latest(from: data, osVersion: sonoma)
        XCTAssertEqual(latest?.build, "100")
    }

    func testMalformedOrEmptyFeedReturnsNil() {
        XCTAssertNil(SparkleAppcast.latest(from: Data("not xml".utf8), osVersion: sonoma))
        XCTAssertNil(SparkleAppcast.latest(from: feed(""), osVersion: sonoma))
    }

    func testHasUpdateComparesBuildThenShortVersion() {
        let release = SparkleRelease(shortVersion: "1.4", build: "140", downloadURL: nil)
        XCTAssertTrue(SparkleAppcast.hasUpdate(release, shortVersion: "1.3", build: "130"))
        XCTAssertFalse(SparkleAppcast.hasUpdate(release, shortVersion: "1.4", build: "140"))
        // No local build: fall back to marketing versions.
        XCTAssertTrue(SparkleAppcast.hasUpdate(release, shortVersion: "1.2", build: ""))
        let shortOnly = SparkleRelease(shortVersion: "2.0", build: nil, downloadURL: nil)
        XCTAssertFalse(SparkleAppcast.hasUpdate(shortOnly, shortVersion: "2.0", build: "99"))
    }

    func testIsNewer() {
        XCTAssertTrue(SparkleAppcast.isNewer("1.10", than: "1.9"))
        XCTAssertTrue(SparkleAppcast.isNewer("2.0.1", than: "2.0"))
        XCTAssertFalse(SparkleAppcast.isNewer("2.0", than: "2.0.0"))
        XCTAssertFalse(SparkleAppcast.isNewer("1.2", than: "1.3"))
    }
}
