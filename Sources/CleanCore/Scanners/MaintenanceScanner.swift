import Foundation

/// Surfaces maintenance actions that can be run via system tools.
/// Each item carries a command in `detail` and metadata in `group`.
public struct MaintenanceScanner: FileScanner {
    public let module: ModuleID = .maintenance

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.5, "Inventaire des tâches…")
        let tasks: [(String, String, String, Severity)] = [
            ("Vider le cache DNS",
             "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder",
             "Résout les soucis de résolution de noms",
             .info),
            ("Reconstruire l'index Spotlight",
             "sudo mdutil -E /",
             "Réindexe le disque — Spotlight redevient rapide",
             .info),
            ("Réparer les permissions du dossier utilisateur",
             "diskutil resetUserPermissions / $(id -u)",
             "Corrige des erreurs d'accès aux fichiers personnels",
             .info),
            ("Forcer un check Time Machine",
             "tmutil startbackup --auto",
             "Lance une sauvegarde immédiate",
             .info),
            ("Purger la mémoire vive inactive",
             "sudo purge",
             "Libère la RAM mise en cache",
             .info),
            ("Nettoyer les receipts d'installations",
             "rm -rf ~/Library/Application\\ Support/com.apple.installer.signing*",
             "Supprime des fichiers temporaires d'installation",
             .info),
        ]

        let items = tasks.enumerated().map { (idx, t) in
            ScanItem(
                url: URL(fileURLWithPath: "/Maintenance/\(idx)"),
                size: 0,
                kind: .maintenanceTask,
                group: "Tâches",
                title: t.0,
                detail: t.2,
                severity: t.3
            )
        }
        progress(1.0, "Done")
        return ScanResult(module: .maintenance, items: items)
    }
}
