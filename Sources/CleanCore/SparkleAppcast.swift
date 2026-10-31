import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A release advertised by a Sparkle appcast feed (`SUFeedURL`).
public struct SparkleRelease: Equatable {
    /// `sparkle:shortVersionString` — the marketing version ("2.4.1").
    public let shortVersion: String?
    /// `sparkle:version` — the build number Sparkle compares to `CFBundleVersion`.
    public let build: String?
    public let downloadURL: URL?

    public init(shortVersion: String?, build: String?, downloadURL: URL?) {
        self.shortVersion = shortVersion
        self.build = build
        self.downloadURL = downloadURL
    }

    public var displayVersion: String { shortVersion ?? build ?? "?" }
}

/// Pure parsing + comparison for Sparkle appcasts. No network, no side effects.
public enum SparkleAppcast {

    /// Returns the newest stable release in an appcast, or nil if none is usable.
    /// Items on a named channel (betas) and items requiring a newer macOS than
    /// `osVersion` are ignored, like Sparkle itself does by default.
    public static func latest(
        from data: Data,
        osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> SparkleRelease? {
        let parser = XMLParser(data: data)
        let delegate = AppcastDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return nil }

        let os = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let candidates = delegate.items.filter { item in
            guard item.channel == nil else { return false }
            if let min = item.minimumSystemVersion, isNewer(min, than: os) { return false }
            return item.build != nil || item.shortVersion != nil
        }
        return candidates
            .map { SparkleRelease(shortVersion: $0.shortVersion, build: $0.build, downloadURL: $0.url) }
            .max { a, b in isNewer(sortKey(b), than: sortKey(a)) }
    }

    /// True when `release` is newer than the installed app. Builds are compared
    /// first (that is what Sparkle does); marketing versions are the fallback.
    public static func hasUpdate(_ release: SparkleRelease, shortVersion: String, build: String) -> Bool {
        if let remoteBuild = release.build, !build.isEmpty {
            return isNewer(remoteBuild, than: build)
        }
        if let remoteShort = release.shortVersion, !shortVersion.isEmpty {
            return isNewer(remoteShort, than: shortVersion)
        }
        return false
    }

    /// Compares "1.2.3" style versions. Returns true if `latest` > `current`.
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        func ints(_ s: String) -> [Int] {
            s.split { !$0.isNumber }.map { Int($0) ?? 0 }
        }
        let l = ints(latest), c = ints(current)
        for i in 0..<max(l.count, c.count) {
            let li = i < l.count ? l[i] : 0
            let ci = i < c.count ? c[i] : 0
            if li > ci { return true }
            if li < ci { return false }
        }
        return false
    }

    private static func sortKey(_ r: SparkleRelease) -> String { r.build ?? r.shortVersion ?? "0" }
}

// MARK: – XML

private final class AppcastDelegate: NSObject, XMLParserDelegate {
    struct Item {
        var shortVersion: String?
        var build: String?
        var url: URL?
        var channel: String?
        var minimumSystemVersion: String?
    }

    private(set) var items: [Item] = []
    private var current: Item?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        text = ""
        switch elementName {
        case "item":
            current = Item()
        case "enclosure" where current != nil:
            // Older appcasts carry the versions as enclosure attributes.
            if let v = attributes["sparkle:version"], current?.build == nil { current?.build = v }
            if let v = attributes["sparkle:shortVersionString"], current?.shortVersion == nil {
                current?.shortVersion = v
            }
            if let u = attributes["url"] { current?.url = URL(string: u) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { text = "" }
        guard current != nil else { return }
        switch elementName {
        case "item":
            if let item = current { items.append(item) }
            current = nil
        case "sparkle:version" where !value.isEmpty:
            current?.build = value
        case "sparkle:shortVersionString" where !value.isEmpty:
            current?.shortVersion = value
        case "sparkle:channel" where !value.isEmpty:
            current?.channel = value
        case "sparkle:minimumSystemVersion" where !value.isEmpty:
            current?.minimumSystemVersion = value
        default:
            break
        }
    }
}
