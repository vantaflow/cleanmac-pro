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

    public init(searchPaths: [URL]? = nil) {
        self.searchPaths = searchPaths ?? [
            URL(fileURLWithPath: "/Applications"),
            FS.home.appendingPathComponent("Applications"),
        ]
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let apps = discoverApps()
        var items: [ScanItem] = []
        let total = Double(max(apps.count, 1))

        for (idx, app) in apps.enumerated() {
            if Task.isCancelled { throw ScanError.cancelled }
            progress(Double(idx) / total, "Analyzing \(app.lastPathComponent)…")
            let bundle = analyze(appURL: app)
            // Add bundle itself
            items.append(ScanItem(
                url: bundle.bundleURL,
                size: bundle.bundleSize,
                kind: .app,
                group: bundle.name
            ))
            // Add residues
            items.append(contentsOf: bundle.residues)
        }
        progress(1.0, "Done")
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

    public func analyze(appURL: URL) -> InstalledApp {
        let name = appURL.deletingPathExtension().lastPathComponent
        let bundleID = readBundleID(appURL) ?? appURL.path
        let bundleSize = FS.directorySize(appURL)

        let residueRoots: [URL] = [
            FS.home.appendingPathComponent("Library/Application Support"),
            FS.home.appendingPathComponent("Library/Caches"),
            FS.home.appendingPathComponent("Library/Preferences"),
            FS.home.appendingPathComponent("Library/Logs"),
            FS.home.appendingPathComponent("Library/Containers"),
            FS.home.appendingPathComponent("Library/Saved Application State"),
        ]

        var residues: [ScanItem] = []
        let needles = Set([bundleID.lowercased(), name.lowercased()])

        for root in residueRoots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries {
                let entryName = entry.lastPathComponent.lowercased()
                let matches = needles.contains(where: { needle in
                    !needle.isEmpty && (entryName == needle || entryName.contains(needle))
                })
                if matches {
                    let size = FS.directorySize(entry)
                    residues.append(ScanItem(
                        url: entry,
                        size: size,
                        modified: FS.modified(of: entry),
                        kind: .appResidue,
                        group: name
                    ))
                }
            }
        }

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
