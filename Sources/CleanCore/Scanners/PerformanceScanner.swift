import Foundation

/// Lists launch agents, login items, and currently top CPU/RAM consumers.
public struct PerformanceScanner: FileScanner {
    public let module: ModuleID = .performance

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []

        progress(0.1, "Éléments de connexion…")
        items.append(contentsOf: loginItems())

        progress(0.4, "Launch agents…")
        items.append(contentsOf: launchAgents())

        progress(0.7, "Top processus…")
        items.append(contentsOf: topProcesses())

        progress(1.0, "Done")
        return ScanResult(module: .performance, items: items)
    }

    private func loginItems() -> [ScanItem] {
        let script = """
        tell application "System Events"
            try
                set itemList to {}
                set the loginItems to login items
                repeat with anItem in loginItems
                    set end of itemList to name of anItem
                end repeat
                return itemList
            on error
                return {}
            end try
        end tell
        """
        let (_, out, _) = Shell.run("/usr/bin/osascript", ["-e", script])
        let names = out
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if names.isEmpty {
            return [ScanItem(
                url: URL(fileURLWithPath: "/LoginItems/none"),
                size: 0,
                kind: .loginItem,
                group: "Éléments de connexion",
                title: "Aucun élément au démarrage",
                detail: "Bon point pour la rapidité de démarrage",
                severity: .good
            )]
        }
        return names.map { name in
            // Escape quotes in the name for the osascript command.
            let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
            return ScanItem(
                url: URL(fileURLWithPath: "/LoginItems/\(name)"),
                size: 0,
                kind: .loginItem,
                group: "Éléments de connexion",
                title: name,
                detail: "S'ouvre à chaque démarrage — clique pour désactiver",
                severity: .info,
                command: "osascript -e 'tell application \"System Events\" to delete login item \"\(escaped)\"'",
                needsAdmin: false
            )
        }
    }

    private func launchAgents() -> [ScanItem] {
        let roots: [(URL, String)] = [
            (FS.home.appendingPathComponent("Library/LaunchAgents"), "Utilisateur"),
            (URL(fileURLWithPath: "/Library/LaunchAgents"),         "Système"),
        ]
        var out: [ScanItem] = []
        for (root, label) in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries where entry.pathExtension == "plist" {
                let name = entry.deletingPathExtension().lastPathComponent
                // User launch agents → can disable without sudo. System ones → admin required.
                let needsAdmin = root.path.hasPrefix("/Library/")
                let domain = needsAdmin ? "system" : "gui/$(id -u)"
                // `bootout` is the modern equivalent of `unload`. Works on macOS 11+.
                let unloadCommand = "launchctl bootout \(domain) \"\(entry.path)\" 2>&1 || launchctl unload \"\(entry.path)\""
                out.append(ScanItem(
                    url: entry,
                    size: FS.size(of: entry),
                    kind: .launchAgent,
                    group: "Launch agents — \(label)",
                    title: name,
                    detail: "\(entry.path) — clique pour décharger",
                    severity: .info,
                    command: unloadCommand,
                    needsAdmin: needsAdmin
                ))
            }
        }
        return out
    }

    private func topProcesses() -> [ScanItem] {
        // Use `ps` for portability — top 10 by RSS.
        let (_, out, _) = Shell.run(
            "/bin/ps",
            ["-Ao", "rss=,pcpu=,comm=", "-r"],
            timeout: 5
        )
        let lines = out.split(separator: "\n").prefix(10)
        var items: [ScanItem] = []
        for raw in lines {
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 3 else { continue }
            let rssKB = Int64(parts[0]) ?? 0
            let cpu = parts[1]
            let comm = parts[2...].joined(separator: " ")
            let label = (comm as NSString).lastPathComponent
            items.append(ScanItem(
                url: URL(fileURLWithPath: comm),
                size: rssKB * 1024,
                kind: .processSnapshot,
                group: "Top mémoire vive",
                title: label,
                detail: "CPU \(cpu) %",
                severity: rssKB > 500_000 ? .warn : .info
            ))
        }
        return items
    }
}
