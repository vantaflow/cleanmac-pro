import Foundation

/// Surfaces real maintenance commands. Each item carries a `command` and a
/// `needsAdmin` flag so the UI can execute it (with a native admin prompt
/// when required).
public struct MaintenanceScanner: FileScanner {
    public let module: ModuleID = .maintenance

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.5, "Inventaire des tâches…")
        let tasks: [(title: String, detail: String, command: String, admin: Bool)] = [
            ("Vider le cache DNS",
             "Résout les soucis de résolution de noms",
             "dscacheutil -flushcache && killall -HUP mDNSResponder",
             true),
            ("Reconstruire l'index Spotlight",
             "Réindexe le disque — Spotlight redevient rapide",
             "mdutil -E /",
             true),
            ("Réparer les permissions utilisateur",
             "Corrige des erreurs d'accès aux fichiers personnels",
             "diskutil resetUserPermissions / $(id -u)",
             false),
            ("Forcer une sauvegarde Time Machine",
             "Lance une sauvegarde immédiate",
             "tmutil startbackup --auto",
             false),
            ("Purger la mémoire vive inactive",
             "Libère la RAM mise en cache (peut prendre 30 s)",
             "purge",
             true),
            ("Vider la corbeille",
             "Demande confirmation au Finder",
             "osascript -e 'tell application \"Finder\" to empty the trash'",
             false),
        ]

        let items = tasks.enumerated().map { (idx, t) in
            ScanItem(
                url: URL(fileURLWithPath: "/Maintenance/\(idx)"),
                size: 0,
                kind: .maintenanceTask,
                group: "Tâches",
                title: t.title,
                detail: t.detail,
                severity: .info,
                command: t.command,
                needsAdmin: t.admin
            )
        }
        progress(1.0, "Done")
        return ScanResult(module: .maintenance, items: items)
    }

    /// Execute a maintenance task. For admin tasks, uses osascript's
    /// "with administrator privileges" which produces a native macOS prompt.
    public static func execute(_ item: ScanItem) -> (status: Int32, output: String) {
        guard let cmd = item.command else { return (-1, "no command") }
        if item.needsAdmin {
            // Use osascript so macOS pops the standard authorization dialog.
            let escaped = cmd
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let script = "do shell script \"\(escaped)\" with administrator privileges"
            let (status, out, err) = Shell.run("/usr/bin/osascript", ["-e", script], timeout: 120)
            return (status, out.isEmpty ? err : out)
        } else {
            let (status, out, err) = Shell.run("/bin/sh", ["-c", cmd], timeout: 120)
            return (status, out.isEmpty ? err : out)
        }
    }
}
