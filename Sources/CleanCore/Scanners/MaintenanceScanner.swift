import Foundation

/// Surfaces real maintenance commands. Each item carries a `command` and a
/// `needsAdmin` flag so the UI can execute it (with a native admin prompt
/// when required).
public struct MaintenanceScanner: FileScanner {
    public let module: ModuleID = .maintenance

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.5, L("Inventaire des tâches…"))
        let tasks: [(title: String, detail: String, command: String, admin: Bool)] = [
            (L("Vider le cache DNS"),
             L("Résout les soucis de résolution de noms"),
             "dscacheutil -flushcache && killall -HUP mDNSResponder",
             true),
            (L("Reconstruire l'index Spotlight"),
             L("Réindexe le disque — Spotlight redevient rapide"),
             "mdutil -E /",
             true),
            (L("Réparer les permissions utilisateur"),
             L("Corrige des erreurs d'accès aux fichiers personnels"),
             "diskutil resetUserPermissions / $(id -u)",
             false),
            (L("Forcer une sauvegarde Time Machine"),
             L("Lance une sauvegarde immédiate"),
             "tmutil startbackup --auto",
             false),
            (L("Purger la mémoire vive inactive"),
             L("Libère la RAM mise en cache (peut prendre 30 s)"),
             "purge",
             true),
            (L("Vider la corbeille"),
             L("Demande confirmation au Finder"),
             "osascript -e 'tell application \"Finder\" to empty the trash'",
             false),
        ]

        let items = tasks.enumerated().map { (idx, t) in
            ScanItem(
                url: URL(fileURLWithPath: "/Maintenance/\(idx)"),
                size: 0,
                kind: .maintenanceTask,
                group: L("Tâches"),
                title: t.title,
                detail: t.detail,
                severity: .info,
                command: t.command,
                needsAdmin: t.admin
            )
        }
        progress(1.0, L("Done"))
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
