import Foundation

/// Lists software updates available via Homebrew and the macOS softwareupdate tool.
public struct UpdatesScanner: FileScanner {
    public let module: ModuleID = .updates

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []

        progress(0.1, "Vérification Homebrew…")
        items.append(contentsOf: brewOutdated())

        progress(0.6, "Vérification macOS…")
        items.append(contentsOf: macOSUpdates())

        progress(1.0, "Done")
        return ScanResult(module: .updates, items: items)
    }

    private func brewOutdated() -> [ScanItem] {
        guard let brew = Shell.which("brew") else {
            return [ScanItem(
                url: URL(fileURLWithPath: "/Homebrew"),
                size: 0,
                kind: .updateAvailable,
                group: "Homebrew",
                title: "Homebrew non installé",
                detail: "Aucune vérification possible",
                severity: .info
            )]
        }
        let (status, out, _) = Shell.run(brew, ["outdated", "--verbose"], timeout: 20)
        guard status == 0 else { return [] }
        let lines = out.split(separator: "\n").map(String.init)
        if lines.isEmpty {
            return [ScanItem(
                url: URL(fileURLWithPath: "/Homebrew/up-to-date"),
                size: 0,
                kind: .updateAvailable,
                group: "Homebrew",
                title: "Homebrew à jour",
                detail: "Aucun paquet obsolète",
                severity: .good
            )]
        }
        return lines.map { line in
            // brew outdated --verbose format: "name (current) < newer"
            let parts = line.components(separatedBy: " ")
            let name = parts.first ?? line
            return ScanItem(
                url: URL(fileURLWithPath: "/Homebrew/\(name)"),
                size: 0,
                kind: .updateAvailable,
                group: "Homebrew",
                title: name,
                detail: line.replacingOccurrences(of: "\(name) ", with: ""),
                severity: .info
            )
        }
    }

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
                    size: 0,
                    kind: .updateAvailable,
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
                size: 0,
                kind: .updateAvailable,
                group: "macOS",
                title: "macOS à jour",
                detail: "Aucune mise à jour disponible",
                severity: .good
            ))
        }
        return items
    }
}
