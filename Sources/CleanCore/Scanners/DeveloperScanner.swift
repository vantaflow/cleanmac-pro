import Foundation

/// A simulator that `simctl` reports as unavailable (its runtime was removed).
public struct UnavailableSimulator: Hashable, Sendable {
    public let name: String
    public let dataPath: String?
}

/// Developer clean-up: Xcode build products, old archives, device support
/// files, simulator caches, package-manager caches, stale `node_modules`,
/// Homebrew and Docker leftovers. File-based findings are trashable; the
/// tool-driven ones (simctl, brew, docker) carry a `command` the UI can run.
///
/// `home` and `projectRoots` are injectable so tests run on fixture trees, and
/// `includeTools: false` skips every external CLI (deterministic, offline).
public struct DeveloperScanner: FileScanner {
    public let module: ModuleID = .developer
    public let home: URL
    public let projectRoots: [URL]
    public let staleAfter: TimeInterval
    public let maxDepth: Int
    public let includeTools: Bool

    public init(home: URL? = nil,
                projectRoots: [URL]? = nil,
                staleAfter: TimeInterval = 90 * 86_400,
                maxDepth: Int = 4,
                includeTools: Bool = true) {
        let h = home ?? FS.home
        self.home = h
        self.projectRoots = projectRoots ?? ["Projects", "Developer", "Code", "src"].map {
            h.appendingPathComponent($0)
        }
        self.staleAfter = staleAfter
        self.maxDepth = maxDepth
        self.includeTools = includeTools
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []
        let now = Date()
        let xcode = home.appendingPathComponent("Library/Developer/Xcode")

        func isDir(_ url: URL) -> Bool {
            var d: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &d) && d.boolValue
        }
        func children(_ url: URL) -> [URL] {
            (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        }
        func dirItem(_ url: URL, group: String, kind: ItemKind,
                     title: String? = nil, detail: String? = nil) -> ScanItem? {
            let size = FS.directorySize(url, shouldCancel: { Task.isCancelled })
            guard size > 0 else { return nil }
            return ScanItem(url: url, size: size, modified: FS.modified(of: url),
                            kind: kind, group: group, title: title, detail: detail)
        }

        // 1. Xcode
        progress(0.05, "Xcode : DerivedData…")
        for child in children(xcode.appendingPathComponent("DerivedData")) where isDir(child) {
            if Task.isCancelled { throw ScanError.cancelled }
            if let it = dirItem(child, group: "Xcode · DerivedData", kind: .cache,
                                detail: "Produits de compilation — recréés au prochain build") {
                items.append(it)
            }
        }

        progress(0.12, "Xcode : archives anciennes…")
        let archivesRoot = xcode.appendingPathComponent("Archives")
        var archives: [URL] = []
        for entry in children(archivesRoot) {
            if entry.pathExtension == "xcarchive" { archives.append(entry) }
            else if isDir(entry) { archives += children(entry).filter { $0.pathExtension == "xcarchive" } }
        }
        for archive in archives where now.timeIntervalSince(FS.modified(of: archive)) > staleAfter {
            if Task.isCancelled { throw ScanError.cancelled }
            let days = Int(now.timeIntervalSince(FS.modified(of: archive)) / 86_400)
            if let it = dirItem(archive, group: "Xcode · Archives anciennes", kind: .oldFile,
                                detail: "Archive vieille de \(days) jours") {
                items.append(it)
            }
        }

        progress(0.2, "Xcode : DeviceSupport…")
        for platform in ["iOS", "watchOS", "tvOS"] {
            for child in children(xcode.appendingPathComponent("\(platform) DeviceSupport")) where isDir(child) {
                if Task.isCancelled { throw ScanError.cancelled }
                if let it = dirItem(child, group: "Xcode · DeviceSupport", kind: .cache,
                                    title: "\(platform) \(child.lastPathComponent)",
                                    detail: "Symboles d'appareil — retéléchargés à la prochaine connexion") {
                    items.append(it)
                }
            }
        }

        progress(0.28, "Simulateurs…")
        let simCaches = home.appendingPathComponent("Library/Developer/CoreSimulator/Caches")
        if isDir(simCaches), let it = dirItem(simCaches, group: "Xcode · Simulateurs", kind: .cache,
                                              title: "Caches des simulateurs") {
            items.append(it)
        }

        // 2. Package-manager caches
        progress(0.4, "Caches de paquets…")
        let caches: [(String, String)] = [
            ("Library/Caches/org.swift.swiftpm", "Cache SwiftPM"),
            (".gradle/caches", "Cache Gradle"),
            (".npm", "Cache npm"),
            ("Library/Caches/Yarn", "Cache Yarn"),
            (".yarn/berry/cache", "Cache Yarn (berry)"),
            ("Library/pnpm/store", "Store pnpm"),
            (".local/share/pnpm/store", "Store pnpm"),
            ("Library/Caches/CocoaPods", "Cache CocoaPods"),
        ]
        for (rel, label) in caches {
            if Task.isCancelled { throw ScanError.cancelled }
            let url = home.appendingPathComponent(rel)
            if isDir(url), let it = dirItem(url, group: "Caches de paquets", kind: .cache,
                                            title: label, detail: "~/\(rel)") {
                items.append(it)
            }
        }

        // 3. node_modules orphelins / anciens
        progress(0.55, "node_modules…")
        var found: [URL] = []
        for root in projectRoots where isDir(root) {
            findNodeModules(in: root, depth: 0, into: &found)
        }
        for nm in found {
            if Task.isCancelled { throw ScanError.cancelled }
            let project = nm.deletingLastPathComponent()
            let pkg = project.appendingPathComponent("package.json")
            let hasPkg = FileManager.default.fileExists(atPath: pkg.path)
            var ref = FS.modified(of: nm)
            if hasPkg { ref = max(ref, FS.modified(of: pkg)) }
            let age = now.timeIntervalSince(ref)
            let detail: String
            if !hasPkg {
                detail = "Orphelin — aucun package.json dans \(project.lastPathComponent)"
            } else if age > staleAfter {
                detail = "Projet inactif depuis \(Int(age / 86_400)) jours"
            } else {
                continue
            }
            if let it = dirItem(nm, group: "node_modules", kind: .cache,
                                title: "\(project.lastPathComponent)/node_modules", detail: detail) {
                items.append(it)
            }
        }

        // 4. External tools
        if includeTools {
            progress(0.7, "Simulateurs indisponibles…")
            items += unavailableSimulatorItem()
            if Task.isCancelled { throw ScanError.cancelled }
            progress(0.8, "Homebrew…")
            items += brewItem()
            if Task.isCancelled { throw ScanError.cancelled }
            progress(0.9, "Docker…")
            items += dockerItem()
        }

        progress(1.0, "Done")
        return ScanResult(module: .developer, items: items)
    }

    // MARK: node_modules discovery

    private func findNodeModules(in dir: URL, depth: Int, into out: inout [URL]) {
        guard depth <= maxDepth else { return }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: Array(keys), options: [])) ?? []
        for e in entries {
            let v = try? e.resourceValues(forKeys: keys)
            guard v?.isDirectory == true, v?.isSymbolicLink != true else { continue }
            let name = e.lastPathComponent
            if name == "node_modules" { out.append(e); continue }
            if name.hasPrefix(".") || name == "Library" || name.hasSuffix(".app") { continue }
            findNodeModules(in: e, depth: depth + 1, into: &out)
        }
    }

    // MARK: tool-driven items

    private func unavailableSimulatorItem() -> [ScanItem] {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: "/usr/bin/xcrun"),
              Shell.run("/usr/bin/xcode-select", ["-p"], timeout: 10).status == 0 else { return [] }
        let r = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "unavailable", "-j"], timeout: 30)
        guard r.status == 0, let data = r.stdout.data(using: .utf8) else { return [] }
        let sims = Self.parseUnavailableSimulators(data)
        guard !sims.isEmpty else { return [] }
        let size = sims.compactMap(\.dataPath).reduce(Int64(0)) {
            $0 + FS.directorySize(URL(fileURLWithPath: $1))
        }
        return [ScanItem(
            url: URL(fileURLWithPath: "/Developer/simulateurs-indisponibles"),
            size: size, kind: .maintenanceTask, group: "Xcode · Simulateurs",
            title: "Supprimer \(sims.count) simulateur(s) indisponible(s)",
            detail: sims.prefix(3).map(\.name).joined(separator: ", "),
            severity: .info,
            command: "/usr/bin/xcrun simctl delete unavailable")]
    }

    private func brewItem() -> [ScanItem] {
        guard let brew = Shell.which("brew") else { return [] }
        let r = Shell.run(brew, ["cleanup", "-n"], timeout: 60)
        guard r.status == 0, let bytes = Self.parseBrewCleanup(r.stdout), bytes > 0 else { return [] }
        return [ScanItem(
            url: URL(fileURLWithPath: "/Developer/homebrew-cleanup"),
            size: bytes, kind: .maintenanceTask, group: "Homebrew",
            title: "brew cleanup", detail: "Anciennes versions et cache téléchargé (estimation)",
            severity: .info, command: "\(Self.shellQuote(brew)) cleanup")]
    }

    private func dockerItem() -> [ScanItem] {
        guard let docker = Shell.which("docker") else { return [] }
        let r = Shell.run(docker, ["system", "df", "--format", "{{.Type}}|{{.Reclaimable}}"], timeout: 30)
        guard r.status == 0, let bytes = Self.parseDockerReclaimable(r.stdout), bytes > 0 else { return [] }
        return [ScanItem(
            url: URL(fileURLWithPath: "/Developer/docker-prune"),
            size: bytes, kind: .maintenanceTask, group: "Docker",
            title: "docker system prune",
            detail: "Conteneurs arrêtés, images et réseaux inutilisés (estimation) — confirmation demandée",
            severity: .warn, command: "\(Self.shellQuote(docker)) system prune -f")]
    }

    // MARK: parsing helpers (public for tests)

    public static func parseUnavailableSimulators(_ json: Data) -> [UnavailableSimulator] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let devices = root["devices"] as? [String: Any] else { return [] }
        var out: [UnavailableSimulator] = []
        for (_, value) in devices {
            for d in (value as? [[String: Any]]) ?? [] {
                if let avail = d["isAvailable"] as? Bool, avail { continue }
                out.append(UnavailableSimulator(name: (d["name"] as? String) ?? "?",
                                                dataPath: d["dataPath"] as? String))
            }
        }
        return out.sorted { $0.name < $1.name }
    }

    /// "This operation would free approximately 1.2GB of disk space."
    public static func parseBrewCleanup(_ output: String) -> Int64? {
        guard let line = output.split(separator: "\n").first(where: { $0.contains("free approximately") })
        else { return nil }
        return parseSize(String(line), base: 1024)
    }

    /// Sums the "Reclaimable" column of `docker system df --format "{{.Type}}|{{.Reclaimable}}"`
    /// (values like "1.2GB (45%)").
    public static func parseDockerReclaimable(_ output: String) -> Int64? {
        var total: Int64 = 0
        var any = false
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, let n = parseSize(String(parts[1]), base: 1000) else { continue }
            total += n
            any = true
        }
        return any ? total : nil
    }

    /// First "<number><unit>B" in a string ("1.5GB", "312 MB", "0B").
    public static func parseSize(_ text: String, base: Double) -> Int64? {
        guard let re = try? NSRegularExpression(pattern: "([0-9]+(?:\\.[0-9]+)?)\\s*([KMGT]?)B", options: [.caseInsensitive]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nr = Range(m.range(at: 1), in: text), let ur = Range(m.range(at: 2), in: text),
              let value = Double(text[nr]) else { return nil }
        let exps: [String: Double] = ["": 0, "K": 1, "M": 2, "G": 3, "T": 4]
        let e = exps[text[ur].uppercased()] ?? 0
        return Int64(value * pow(base, e))
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
