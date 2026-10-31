import Foundation

/// Paths and app identifiers the user never wants to be offered again.
/// Filtering is centralised in `apply(to:)` / `FileScanner.scanFiltered`, so
/// every scanner benefits without knowing about exclusions.
public struct ExclusionList: Codable, Equatable, Sendable {
    public var paths: [String]
    public var appIDs: [String]

    public init(paths: [String] = [], appIDs: [String] = []) {
        self.paths = paths.map(Self.normalize)
        self.appIDs = appIDs
    }

    public var isEmpty: Bool { paths.isEmpty && appIDs.isEmpty }

    /// Standardised absolute path without trailing slash (except root).
    public static func normalize(_ path: String) -> String {
        var p = (path as NSString).standardizingPath
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// True when `path` is the excluded path itself or lives beneath it.
    /// Compares on a path-component boundary: excluding `/a/b` does not
    /// exclude `/a/bc`.
    public static func path(_ path: String, isUnder excluded: String) -> Bool {
        let p = normalize(path), e = normalize(excluded)
        if e == "/" { return true }
        return p == e || p.hasPrefix(e + "/")
    }

    public mutating func addPath(_ path: String) {
        let n = Self.normalize(path)
        if !paths.contains(n) { paths.append(n) }
    }

    public mutating func addAppID(_ id: String) {
        let t = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty && !appIDs.contains(t) { appIDs.append(t) }
    }

    public mutating func removePath(_ path: String) { paths.removeAll { $0 == Self.normalize(path) } }
    public mutating func removeAppID(_ id: String) { appIDs.removeAll { $0 == id } }

    /// Bundle identifier of an `.app` bundle on disk, if readable.
    public static func bundleID(ofAppAt url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    public func isExcluded(_ item: ScanItem,
                           bundleID: (URL) -> String? = ExclusionList.bundleID(ofAppAt:)) -> Bool {
        if paths.contains(where: { Self.path(item.url.path, isUnder: $0) }) { return true }
        // A folder row stands for everything inside it: if the user excluded
        // something *inside* it, the whole folder must not be offered for cleaning.
        if item.fileCount != nil, paths.contains(where: { Self.path($0, isUnder: item.url.path) }) { return true }
        guard !appIDs.isEmpty else { return false }
        switch item.kind {
        case .app:
            guard let id = bundleID(item.url) else { return false }
            return appIDs.contains { $0.caseInsensitiveCompare(id) == .orderedSame }
        case .appResidue:
            // Residues are named after the app's bundle id (caches, prefs, containers…).
            let haystack = item.url.path.lowercased()
            return appIDs.contains { haystack.contains($0.lowercased()) }
        case .cache, .log, .tempFile:
            // Cache folders are named after the owning app's bundle id.
            guard item.fileCount != nil else { return false }
            let name = item.url.lastPathComponent.lowercased()
            return appIDs.contains { name == $0.lowercased() || name.hasPrefix($0.lowercased() + ".") }
        default:
            return false
        }
    }

    public func apply(to items: [ScanItem],
                      bundleID: (URL) -> String? = ExclusionList.bundleID(ofAppAt:)) -> [ScanItem] {
        guard !isEmpty else { return items }
        return items.filter { !isExcluded($0, bundleID: bundleID) }
    }

    public func apply(to result: ScanResult) -> ScanResult {
        ScanResult(module: result.module, items: apply(to: result.items), scannedAt: result.scannedAt)
    }

    // MARK: Persistence

    public static func fileURL(in dir: URL = AppSupport.defaultDirectory) -> URL {
        dir.appendingPathComponent("exclusions.json")
    }

    public static func load(from dir: URL = AppSupport.defaultDirectory) -> ExclusionList {
        AppSupport.load(ExclusionList.self, from: fileURL(in: dir)) ?? ExclusionList()
    }

    public func save(to dir: URL = AppSupport.defaultDirectory) throws {
        try AppSupport.save(self, to: Self.fileURL(in: dir))
    }
}

public extension FileScanner {
    /// The single place where exclusions are applied after a scan.
    func scanFiltered(exclusions: ExclusionList = .load(),
                      progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        exclusions.apply(to: try await scan(progress: progress))
    }
}
