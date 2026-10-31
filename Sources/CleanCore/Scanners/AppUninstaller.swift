import Foundation

public struct InstalledApp: Identifiable, Hashable {
    public let id: String          // bundle identifier (or path fallback)
    public let name: String        // display name (no .app)
    public let bundleURL: URL      // /Applications/Foo.app
    public let bundleSize: Int64
    public let residues: [ScanItem]

    public var totalSize: Int64 { bundleSize + residues.reduce(0) { $0 + $1.size } }
}

public struct AppUninstaller: FileScanner {
    public let module: ModuleID = .uninstaller
    public let searchPaths: [URL]
    /// Also list leftovers of apps that are no longer installed ("Restes d'apps supprimées").
    public let includeOrphans: Bool

    public init(searchPaths: [URL]? = nil, includeOrphans: Bool = true) {
        self.includeOrphans = includeOrphans
        self.searchPaths = searchPaths ?? [
            URL(fileURLWithPath: "/Applications"),
            FS.home.appendingPathComponent("Applications"),
        ]
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let apps = discoverApps()
        var items: [ScanItem] = []
        let total = Double(max(apps.count, 1)) + 1
        let index = AppIndex.build(roots: AppIndex.defaultRoots + searchPaths)

        for (idx, app) in apps.enumerated() {
            if Task.isCancelled { throw ScanError.cancelled }
            progress(Double(idx) / total, L("Analyzing \(app.lastPathComponent)…"))
            let bundle = analyze(appURL: app, index: index)
            items.append(ScanItem(
                url: bundle.bundleURL,
                size: bundle.bundleSize,
                kind: .app,
                group: bundle.name
            ))
            items.append(contentsOf: bundle.residues)
        }
        if includeOrphans {
            if Task.isCancelled { throw ScanError.cancelled }
            progress(Double(apps.count) / total, L("Recherche des restes d'apps supprimées…"))
            var full = index
            full.extraIDs.formUnion(AppIndex.spotlightIDs())
            for o in AppLeftovers().orphans(index: full) { items.append(contentsOf: o.items) }
        }
        progress(1.0, L("Done"))
        return ScanResult(module: .uninstaller, items: items)
    }

    private func discoverApps() -> [URL] {
        var out: [URL] = []
        for path in searchPaths {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: nil
            ) else { continue }
            out.append(contentsOf: entries.filter { $0.pathExtension == "app" })
        }
        return out
    }

    public func analyze(appURL: URL, index: AppIndex? = nil) -> InstalledApp {
        let name = appURL.deletingPathExtension().lastPathComponent
        let bundleID = readBundleID(appURL) ?? appURL.path
        let bundleSize = FS.directorySize(appURL)
        let idx = index ?? AppIndex.build(roots: AppIndex.defaultRoots + searchPaths)
        let residues = AppLeftovers().find(
            bundleID: bundleID, name: name,
            otherInstalledIDs: idx.knownIDs(excluding: bundleID),
            otherInstalledNames: idx.knownNames(excluding: bundleID))

        return InstalledApp(
            id: bundleID,
            name: name,
            bundleURL: appURL,
            bundleSize: bundleSize,
            residues: residues
        )
    }

    private func readBundleID(_ appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleIdentifier"] as? String
    }
}
