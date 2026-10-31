import Foundation

// Pure, read-only logic to find the files an app leaves behind in ~/Library.
// Shared by the Uninstaller (residues of an installed app), the orphan scan
// ("Restes d'apps supprimées") and the removal watcher (residues of an app
// that just vanished). Matching is deliberately conservative: exact bundle id,
// a "<bundle id>.<suffix>" prefix (helpers, extensions), a known Team-ID /
// "group." prefix for Group Containers, or an exact app name in the few
// folders apps name after themselves. Never a substring match.

/// One app found on disk.
public struct InstalledAppRecord: Hashable, Sendable, Codable {
    public let bundleID: String
    public let name: String
    public let path: String
    /// Bundle ids of helpers / extensions shipped inside the app.
    public let nestedIDs: [String]

    public init(bundleID: String, name: String, path: String, nestedIDs: [String] = []) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
        self.nestedIDs = nestedIDs
    }
}

/// Snapshot of the installed apps (bundle id <-> path).
public struct AppIndex: Sendable {
    public private(set) var apps: [InstalledAppRecord]
    /// Extra bundle ids known to be installed (Spotlight, running apps…), lowercased.
    public var extraIDs: Set<String>

    public init(apps: [InstalledAppRecord] = [], extraIDs: Set<String> = []) {
        self.apps = apps
        self.extraIDs = Set(extraIDs.map { $0.lowercased() })
    }

    public static var defaultRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"),
         FS.home.appendingPathComponent("Applications"),
         URL(fileURLWithPath: "/System/Applications"),
         URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"),
         URL(fileURLWithPath: "/Applications/Utilities")]
    }

    /// Walks `roots` (descending up to two levels into plain sub-folders such as
    /// `Utilities`, `Setapp` or vendor folders) and reads each bundle's Info.plist.
    public static func build(roots: [URL] = defaultRoots, extraIDs: Set<String> = []) -> AppIndex {
        var apps: [InstalledAppRecord] = []
        var seen = Set<String>()
        for root in roots { collect(root, depth: 0, into: &apps, seen: &seen) }
        return AppIndex(apps: apps, extraIDs: extraIDs)
    }

    private static func collect(_ dir: URL, depth: Int, into apps: inout [InstalledAppRecord], seen: inout Set<String>) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]
        ) else { return }
        for e in entries {
            if e.pathExtension == "app" {
                let path = e.standardizedFileURL.path
                guard seen.insert(path).inserted, let rec = record(forApp: e) else { continue }
                apps.append(rec)
            } else if depth < 2,
                      let v = try? e.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      v.isDirectory == true, v.isSymbolicLink != true {
                collect(e, depth: depth + 1, into: &apps, seen: &seen)
            }
        }
    }

    /// Reads an `.app` bundle (installed or sitting in the Trash).
    public static func record(forApp url: URL) -> InstalledAppRecord? {
        guard let id = bundleID(of: url) else { return nil }
        var nested: [String] = []
        let fm = FileManager.default
        for sub in ["Contents/Library/LoginItems", "Contents/PlugIns", "Contents/XPCServices",
                    "Contents/Library/LaunchServices", "Contents/Library/SystemExtensions"] {
            let dir = url.appendingPathComponent(sub)
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for it in items { if let nid = bundleID(of: it) { nested.append(nid) } }
        }
        return InstalledAppRecord(bundleID: id,
                                  name: url.deletingPathExtension().lastPathComponent,
                                  path: url.standardizedFileURL.path,
                                  nestedIDs: nested)
    }

    static func bundleID(of bundle: URL) -> String? {
        let plistURL = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let id = plist["CFBundleIdentifier"] as? String, !id.isEmpty
        else { return nil }
        return id
    }

    /// Bundle ids of every app Spotlight knows (other volumes, Downloads, build dirs…):
    /// anything installed anywhere must never be reported as removed. Empty when
    /// `mdfind` is unavailable.
    public static func spotlightIDs(timeout: TimeInterval = 20) -> Set<String> {
        let r = Shell.run("/usr/bin/mdfind", ["kMDItemContentType == 'com.apple.application-bundle'"], timeout: timeout)
        guard r.status == 0 else { return [] }
        var ids = Set<String>()
        for line in r.stdout.split(separator: "\n") {
            let u = URL(fileURLWithPath: String(line))
            guard u.pathExtension == "app", !u.path.contains("/.Trash/") else { continue }
            if let rec = record(forApp: u) { ids.insert(rec.bundleID.lowercased()); rec.nestedIDs.forEach { ids.insert($0.lowercased()) } }
        }
        return ids
    }

    /// Lowercased ids of everything installed, optionally leaving one app out.
    public func knownIDs(excluding bundleID: String? = nil) -> Set<String> {
        let skip = bundleID?.lowercased()
        var out = extraIDs
        for a in apps where a.bundleID.lowercased() != skip {
            out.insert(a.bundleID.lowercased())
            a.nestedIDs.forEach { out.insert($0.lowercased()) }
        }
        if let skip { out.remove(skip) }
        return out
    }

    /// Lowercased names of installed apps, optionally leaving one bundle id out.
    public func knownNames(excluding bundleID: String? = nil) -> Set<String> {
        let skip = bundleID?.lowercased()
        return Set(apps.filter { $0.bundleID.lowercased() != skip }.map { $0.name.lowercased() })
    }

    public func isInstalled(bundleID: String) -> Bool {
        let id = bundleID.lowercased()
        return extraIDs.contains(id) || apps.contains { $0.bundleID.lowercased() == id }
    }
}

/// Leftovers of one orphaned (uninstalled) app.
public struct OrphanApp: Hashable, @unchecked Sendable {
    public let bundleID: String
    public let displayName: String
    public let items: [ScanItem]
    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

public struct AppLeftovers: Sendable {
    public let library: URL

    public init(library: URL = FS.home.appendingPathComponent("Library")) {
        self.library = library
    }

    enum Naming { case bundleID, name }

    struct Location {
        let path: String            // relative to ~/Library
        let allowName: Bool         // folder may be named after the app (exact name)
        let groupPrefixes: Bool     // "group.<id>" / "<TEAMID>.<id>"
    }

    static let locations: [Location] = [
        .init(path: "Application Support", allowName: true, groupPrefixes: false),
        .init(path: "Caches", allowName: true, groupPrefixes: false),
        .init(path: "Containers", allowName: false, groupPrefixes: false),
        .init(path: "Group Containers", allowName: false, groupPrefixes: true),
        .init(path: "Preferences", allowName: false, groupPrefixes: false),
        .init(path: "Preferences/ByHost", allowName: false, groupPrefixes: false),
        .init(path: "Saved Application State", allowName: false, groupPrefixes: false),
        .init(path: "HTTPStorages", allowName: false, groupPrefixes: false),
        .init(path: "WebKit", allowName: false, groupPrefixes: false),
        .init(path: "Logs", allowName: true, groupPrefixes: false),
        .init(path: "LaunchAgents", allowName: false, groupPrefixes: false),
        .init(path: "Cookies", allowName: false, groupPrefixes: false),
        .init(path: "Application Scripts", allowName: false, groupPrefixes: false),
    ]

    // MARK: Entry-name parsing

    static let knownSuffixes = [".plist", ".savedstate", ".binarycookies", ".lockfile"]

    /// Strips the file extension apps/system add around a bundle id.
    static func stripSuffix(_ name: String) -> String {
        var n = name
        let lower = n.lowercased()
        for s in knownSuffixes where lower.hasSuffix(s) { n = String(n.dropLast(s.count)); break }
        return n
    }

    /// Removes `group.` or a 10-char Team ID prefix (`ABCDE12345.`).
    static func stripGroupPrefix(_ name: String) -> String {
        if name.lowercased().hasPrefix("group.") { return String(name.dropFirst(6)) }
        if let dot = name.firstIndex(of: "."), name.distance(from: name.startIndex, to: dot) == 10 {
            let team = name[name.startIndex..<dot]
            if team.allSatisfy({ ($0.isASCII && $0.isUppercase) || $0.isNumber }) {
                return String(name[name.index(after: dot)...])
            }
        }
        return name
    }

    /// ByHost preferences end with a host UUID component.
    static func stripHostUUID(_ id: String) -> String {
        guard let dot = id.lastIndex(of: ".") else { return id }
        let tail = id[id.index(after: dot)...]
        return UUID(uuidString: String(tail)) != nil ? String(id[..<dot]) : id
    }

    static let tlds: Set<String> = [
        "com", "org", "net", "io", "app", "dev", "ai", "co", "me", "fr", "de", "es", "uk", "us", "eu",
        "ru", "cn", "jp", "tv", "cc", "info", "tech", "xyz", "one", "cloud", "so", "sh", "to", "ly",
        "im", "ma", "tn", "ch", "nl", "it", "ca", "au", "se", "no", "dk", "fi", "be", "at", "pl", "pt",
        "br", "in", "kr", "tw", "hk", "sg", "nz", "il", "ie", "gr", "cz", "ua", "tr", "mx", "ar", "za", "ae",
    ]

    /// System and developer-tool namespaces that are not apps (never reported as orphans).
    static let toolingPrefixes = ["com.apple.", "apple.", "org.swift.", "org.llvm.", "org.python.", "com.openssh."]

    /// True for reverse-DNS-looking ids (`com.vendor.App`): at least three components, known TLD.
    static func looksLikeBundleID(_ id: String) -> Bool {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        guard tlds.contains(parts[0].lowercased()) else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return parts.allSatisfy { $0.unicodeScalars.allSatisfy(allowed.contains) }
    }

    /// First two components (`com.google`) — the vendor namespace.
    static func vendor(_ id: String) -> String {
        id.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Candidate bundle id carried by a ~/Library entry name, or nil.
    static func candidateID(entryName: String, in location: Location) -> String? {
        var id = stripSuffix(entryName)
        if location.path == "Preferences/ByHost" { id = stripHostUUID(id) }
        if location.groupPrefixes { id = stripGroupPrefix(id) }
        return looksLikeBundleID(id) ? id : nil
    }

    /// `entryID` belongs to `bundleID`: same id, or "<bundleID>.<suffix>" when the
    /// bundle id is specific enough (3+ components) for a prefix to be unambiguous.
    static func belongs(_ entryID: String, to bundleID: String) -> Bool {
        let e = entryID.lowercased(), b = bundleID.lowercased()
        if e == b { return true }
        guard b.split(separator: ".").count >= 3 else { return false }
        return e.hasPrefix(b + ".")
    }

    /// Entry is owned by one of the other installed apps (exact or helper prefix).
    static func belongsToAny(_ entryID: String, of others: Set<String>) -> Bool {
        let e = entryID.lowercased()
        for o in others {
            if e == o { return true }
            if o.split(separator: ".").count >= 3 && e.hasPrefix(o + ".") { return true }
        }
        return false
    }

    // MARK: Entry enumeration

    private func entries(in location: Location) -> [URL] {
        let dir = library.appendingPathComponent(location.path)
        guard let all = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []
        ) else { return [] }
        return all.filter {
            (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
            && $0.lastPathComponent != ".DS_Store"
            && $0.lastPathComponent != ".localized"
        }
    }

    static func sizeOfEntry(_ url: URL) -> Int64 {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        return isDir ? FS.directorySize(url) : FS.size(of: url)
    }

    // MARK: Residues of a known app

    /// Leftovers of the app `bundleID` / `name`. `otherInstalledIDs` and
    /// `otherInstalledNames` (lowercased) describe every *other* installed app so
    /// a shared folder is never claimed.
    public func find(bundleID: String, name: String,
                     otherInstalledIDs: Set<String> = [],
                     otherInstalledNames: Set<String> = [],
                     group: String? = nil) -> [ScanItem] {
        let groupName = group ?? name
        let nameKey = name.trimmingCharacters(in: .whitespaces).lowercased()
        let idKnown = bundleID.split(separator: ".").count >= 2 && !bundleID.contains("/")
        let nameUsable = nameKey.count >= 3 && !otherInstalledNames.contains(nameKey)

        var out: [ScanItem] = []
        for loc in Self.locations {
            for entry in entries(in: loc) {
                let entryName = entry.lastPathComponent
                var matched = false
                if idKnown {
                    let id = Self.candidateID(entryName: entryName, in: loc) ?? {
                        // Not reverse-DNS-shaped (e.g. exotic ids): accept the exact id only.
                        var raw = Self.stripSuffix(entryName)
                        if loc.path == "Preferences/ByHost" { raw = Self.stripHostUUID(raw) }
                        if loc.groupPrefixes { raw = Self.stripGroupPrefix(raw) }
                        return raw.lowercased() == bundleID.lowercased() ? raw : nil
                    }()
                    if let id, Self.belongs(id, to: bundleID), !Self.belongsToAny(id, of: otherInstalledIDs) {
                        matched = true
                    }
                }
                if !matched, loc.allowName, nameUsable, entryName.lowercased() == nameKey { matched = true }
                guard matched else { continue }
                if loc.path == "LaunchAgents", Self.launchAgentTargetExists(entry) { continue }
                out.append(ScanItem(url: entry,
                                    size: Self.sizeOfEntry(entry),
                                    modified: FS.modified(of: entry),
                                    kind: .appResidue,
                                    group: groupName))
            }
        }
        return out
    }

    /// A LaunchAgent whose program is still on disk (and not inside a leftover
    /// app folder) is a live tool, not a leftover.
    static func launchAgentTargetExists(_ plist: URL) -> Bool {
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return false }
        let program = (dict["Program"] as? String) ?? (dict["ProgramArguments"] as? [String])?.first
        guard let program, program.hasPrefix("/") else { return false }
        return FileManager.default.fileExists(atPath: program)
    }

    // MARK: Orphans

    /// Leftovers whose bundle id matches no installed app. Results are grouped per
    /// bundle id, largest first. Anything sharing a vendor namespace with an
    /// installed app (`com.microsoft.*` while Word is installed) is skipped.
    public func orphans(index: AppIndex, minimumBytes: Int64 = 0) -> [OrphanApp] {
        let known = index.knownIDs()
        let vendors = Set(known.map(Self.vendor))
        var byID: [String: (id: String, urls: [URL])] = [:]

        for loc in Self.locations {
            for entry in entries(in: loc) {
                guard let id = Self.candidateID(entryName: entry.lastPathComponent, in: loc) else { continue }
                let lower = id.lowercased()
                if Self.toolingPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
                if Self.belongsToAny(lower, of: known) { continue }
                // Entry is a parent namespace of an installed app (com.foo for com.foo.bar).
                if known.contains(where: { $0.hasPrefix(lower + ".") }) { continue }
                if vendors.contains(Self.vendor(lower)) { continue }
                if loc.path == "LaunchAgents", Self.launchAgentTargetExists(entry) { continue }
                byID[lower, default: (id, [])].urls.append(entry)
            }
        }

        var result: [OrphanApp] = []
        for (_, v) in byID {
            let display = v.id.split(separator: ".").last.map(String.init) ?? v.id
            let group = L("\(display) (supprimée)")
            let items = v.urls.map { u in
                ScanItem(url: u, size: Self.sizeOfEntry(u), modified: FS.modified(of: u),
                         kind: .appResidue, group: group, detail: v.id)
            }
            let app = OrphanApp(bundleID: v.id, displayName: display, items: items)
            if app.totalSize >= minimumBytes { result.append(app) }
        }
        return result.sorted { $0.totalSize > $1.totalSize }
    }
}
