import Foundation

/// Lists software updates from three sources:
/// 1. Installed .app bundles — versions checked against iTunes Search API
///    for App Store apps (real "update available" detection à la CleanMyMac)
/// 2. Homebrew + Homebrew Cask outdated
/// 3. macOS softwareupdate -l
public struct UpdatesScanner: FileScanner {
    public let module: ModuleID = .updates

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []

        progress(0.05, "Inventaire des apps installées…")
        items.append(contentsOf: await installedAppsWithUpdateCheck(progress: progress))

        progress(0.75, "Vérification Homebrew…")
        items.append(contentsOf: brewOutdated())

        progress(0.92, "Vérification macOS…")
        items.append(contentsOf: macOSUpdates())

        progress(1.0, "Done")
        return ScanResult(module: .updates, items: items)
    }

    // MARK: – Installed apps with real update-available check (CleanMyMac-style)

    private struct AppInfo {
        let url: URL
        let name: String
        let version: String
        let bundleID: String
        let isMAS: Bool
        let isSparkle: Bool
    }

    private func discoverApps() -> [AppInfo] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            FS.home.appendingPathComponent("Applications"),
        ]
        var apps: [AppInfo] = []
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                let plistURL = entry.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plistURL),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                let name = (plist["CFBundleDisplayName"] as? String)
                    ?? (plist["CFBundleName"] as? String)
                    ?? entry.deletingPathExtension().lastPathComponent
                let version = (plist["CFBundleShortVersionString"] as? String) ?? "?"
                let bundleID = (plist["CFBundleIdentifier"] as? String) ?? ""
                let masPath = entry.appendingPathComponent("Contents/_MASReceipt").path
                let sparklePath = entry.appendingPathComponent("Contents/Frameworks/Sparkle.framework").path
                apps.append(AppInfo(
                    url: entry, name: name, version: version, bundleID: bundleID,
                    isMAS: FileManager.default.fileExists(atPath: masPath),
                    isSparkle: FileManager.default.fileExists(atPath: sparklePath)
                ))
            }
        }
        return apps.sorted { $0.name < $1.name }
    }

    /// Compares "1.2.3" style versions. Returns true if `latest` > `current`.
    private func isNewer(latest: String, than current: String) -> Bool {
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

    /// Calls iTunes Search API for an MAS app's latest version. Network with 4s timeout.
    private func macAppStoreLatest(bundleID: String) async -> (version: String, trackURL: String)? {
        guard !bundleID.isEmpty,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=fr&entity=macSoftware")
        else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 4)
        req.setValue("CleanMacPro/2", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let ver = first["version"] as? String
        else { return nil }
        let track = first["trackViewUrl"] as? String ?? ""
        return (ver, track)
    }

    private func installedAppsWithUpdateCheck(progress: @escaping (Double, String) -> Void) async -> [ScanItem] {
        let apps = discoverApps()
        var items: [ScanItem] = []
        let total = Double(max(apps.count, 1))

        // Look up MAS apps in parallel for speed
        await withTaskGroup(of: ScanItem?.self) { group in
            for (idx, app) in apps.enumerated() {
                group.addTask { [self] in
                    progress(0.1 + 0.6 * Double(idx) / total, "Vérifie \(app.name)…")
                    return await self.buildItem(for: app)
                }
            }
            for await item in group {
                if let item { items.append(item) }
            }
        }
        // Group order: updates available first, then by name
        items.sort { a, b in
            let aPriority = a.severity == .warn || a.severity == .bad ? 0 : 1
            let bPriority = b.severity == .warn || b.severity == .bad ? 0 : 1
            if aPriority != bPriority { return aPriority < bPriority }
            return (a.title ?? "") < (b.title ?? "")
        }
        return items
    }

    private func buildItem(for app: AppInfo) async -> ScanItem? {
        let channel = app.isMAS ? "App Store" : (app.isSparkle ? "Direct (Sparkle)" : "Direct")

        if app.isMAS, let latest = await macAppStoreLatest(bundleID: app.bundleID) {
            let hasUpdate = isNewer(latest: latest.version, than: app.version)
            if hasUpdate {
                let upgradeCmd = "open \"\(latest.trackURL)\""
                return ScanItem(
                    url: app.url,
                    size: FS.size(of: app.url),
                    modified: FS.modified(of: app.url),
                    kind: .updateAvailable,
                    group: "Apps · \(channel)",
                    title: "\(app.name) — v\(app.version) → v\(latest.version)",
                    detail: "Mise à jour disponible · ouvre l'App Store",
                    severity: .warn,
                    command: upgradeCmd,
                    needsAdmin: false
                )
            } else {
                return ScanItem(
                    url: app.url,
                    size: FS.size(of: app.url),
                    modified: FS.modified(of: app.url),
                    kind: .updateAvailable,
                    group: "Apps · \(channel)",
                    title: "\(app.name) — v\(app.version)",
                    detail: "À jour",
                    severity: .good
                )
            }
        }

        // Sparkle / direct apps: we don't fetch feeds (slow + flaky).
        return ScanItem(
            url: app.url,
            size: FS.size(of: app.url),
            modified: FS.modified(of: app.url),
            kind: .updateAvailable,
            group: "Apps · \(channel)",
            title: "\(app.name) — v\(app.version)",
            detail: app.isSparkle ? "Vérification via Sparkle dans l'app"
                                  : "Vérification manuelle · \(app.bundleID)",
            severity: .info,
            command: "open -a \"\(app.url.path)\"",
            needsAdmin: false
        )
    }

    // MARK: – Homebrew

    private func brewOutdated() -> [ScanItem] {
        guard let brew = Shell.which("brew") else { return [] }
        var items: [ScanItem] = []

        // Formulae
        let (status, out, _) = Shell.run(brew, ["outdated", "--verbose"], timeout: 30)
        if status == 0 {
            let lines = out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            for line in lines {
                let parts = line.components(separatedBy: " ")
                let name = parts.first ?? line
                items.append(ScanItem(
                    url: URL(fileURLWithPath: "/Homebrew/\(name)"),
                    size: 0, kind: .updateAvailable,
                    group: "Homebrew · formulae",
                    title: name,
                    detail: line.replacingOccurrences(of: "\(name) ", with: ""),
                    severity: .warn,
                    // Use absolute brew path so the subshell finds it.
                    command: "\(brew) upgrade \(name)",
                    needsAdmin: false
                ))
            }
        }

        // Casks (apps installed via brew)
        let (statusC, outC, _) = Shell.run(brew, ["outdated", "--cask", "--verbose"], timeout: 30)
        if statusC == 0 {
            for raw in outC.split(separator: "\n") {
                let line = String(raw)
                let parts = line.components(separatedBy: " ")
                let name = parts.first ?? line
                guard !name.isEmpty else { continue }
                items.append(ScanItem(
                    url: URL(fileURLWithPath: "/Homebrew/casks/\(name)"),
                    size: 0, kind: .updateAvailable,
                    group: "Homebrew · casks",
                    title: name,
                    detail: line.replacingOccurrences(of: "\(name) ", with: ""),
                    severity: .warn,
                    command: "\(brew) upgrade --cask \(name)",
                    needsAdmin: false
                ))
            }
        }

        if items.isEmpty && Shell.which("brew") != nil {
            items.append(ScanItem(
                url: URL(fileURLWithPath: "/Homebrew/up-to-date"),
                size: 0, kind: .updateAvailable,
                group: "Homebrew",
                title: "Homebrew à jour",
                detail: "Aucun paquet obsolète", severity: .good
            ))
        }
        return items
    }

    // MARK: – macOS

    private func macOSUpdates() -> [ScanItem] {
        let (status, out, _) = Shell.run("/usr/sbin/softwareupdate", ["-l"], timeout: 30)
        guard status == 0 else { return [] }
        var items: [ScanItem] = []
        for raw in out.split(separator: "\n") {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("* Label:") {
                let label = line.replacingOccurrences(of: "* Label:", with: "").trimmingCharacters(in: .whitespaces)
                items.append(ScanItem(
                    url: URL(fileURLWithPath: "/macOS/\(label)"),
                    size: 0, kind: .updateAvailable,
                    group: "macOS",
                    title: label,
                    detail: "Mise à jour système disponible",
                    severity: line.lowercased().contains("security") ? .bad : .warn
                ))
            }
        }
        if items.isEmpty {
            items.append(ScanItem(
                url: URL(fileURLWithPath: "/macOS/up-to-date"),
                size: 0, kind: .updateAvailable,
                group: "macOS",
                title: "macOS à jour",
                detail: "Aucune mise à jour disponible",
                severity: .good
            ))
        }
        return items
    }
}
