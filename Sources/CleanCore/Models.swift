import Foundation

public struct ScanItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let size: Int64
    public let modified: Date
    public let kind: ItemKind
    public let group: String?
    public let title: String?        // overrides url.lastPathComponent when set
    public let detail: String?       // secondary description
    public let severity: Severity    // for findings / updates
    public let command: String?      // shell command for executable items
    public let needsAdmin: Bool      // whether command requires root
    public let sparkleRelease: SparkleRelease?  // set when the app can be updated in place
    /// Number of files represented by this row when it stands for a whole
    /// folder (a cache folder grouped per app); `nil` for a single file.
    public let fileCount: Int?

    public init(
        id: UUID = UUID(),
        url: URL,
        size: Int64,
        modified: Date = Date(),
        kind: ItemKind,
        group: String? = nil,
        title: String? = nil,
        detail: String? = nil,
        severity: Severity = .info,
        command: String? = nil,
        needsAdmin: Bool = false,
        sparkleRelease: SparkleRelease? = nil,
        fileCount: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.size = size
        self.modified = modified
        self.kind = kind
        self.group = group
        self.title = title
        self.detail = detail
        self.severity = severity
        self.command = command
        self.needsAdmin = needsAdmin
        self.sparkleRelease = sparkleRelease
        self.fileCount = fileCount
    }

    /// Same item with another size (used to retry only what is left on disk
    /// after a partial deletion).
    public func resized(_ newSize: Int64) -> ScanItem {
        ScanItem(id: id, url: url, size: newSize, modified: modified, kind: kind, group: group,
                 title: title, detail: detail, severity: severity, command: command,
                 needsAdmin: needsAdmin, sparkleRelease: sparkleRelease, fileCount: fileCount)
    }

    public var name: String { title ?? url.lastPathComponent }
}

public enum Severity: String, Hashable, Sendable {
    case info, good, warn, bad
}

public enum ItemKind: String, Hashable, Sendable {
    case cache, log, trash, tempFile
    case largeFile, oldFile
    case app, appResidue
    case duplicate
    // New domains
    case securityFinding
    case updateAvailable
    case launchAgent, loginItem, processSnapshot
    case privacyData
    case maintenanceTask
    case spaceFolder
    case keeper   // best photo of a similar group: shown, never cleaned
}

/// What happens to an item when the user cleans it.
public enum DeletionPolicy: String, Hashable, Sendable {
    /// Removed for good (`removeItem`, admin fallback `rm -rf`): the item comes
    /// back by itself or is already garbage, so the Trash would only hide the
    /// fact that no disk space was freed.
    case permanent
    /// Moved to the Trash: a personal file the user may want back.
    case trash
    /// Never cleaned by `Cleaner` (findings, tasks, update rows, …).
    case none
}

extension ItemKind {
    /// Caches, logs and temporary files are rebuilt by the system / apps on
    /// demand: removing them is lossless.
    public var isRegenerable: Bool {
        switch self {
        case .cache, .log, .tempFile: return true
        default: return false
        }
    }

    /// Files that belong to the user (documents, downloads, photos…). These are
    /// never touched without an explicit review and always go to the Trash.
    public var isPersonalFile: Bool {
        switch self {
        case .largeFile, .oldFile, .duplicate: return true
        default: return false
        }
    }

    public var deletionPolicy: DeletionPolicy {
        switch self {
        case .cache, .log, .tempFile, .trash:
            return .permanent
        case .largeFile, .oldFile, .duplicate, .privacyData, .app, .appResidue:
            return .trash
        case .securityFinding, .updateAvailable, .launchAgent, .loginItem, .processSnapshot,
             .maintenanceTask, .spaceFolder, .keeper:
            return .none
        }
    }

    /// Can `Cleaner` act on this kind of row at all?
    public var isCleanable: Bool { deletionPolicy != .none }
}

public struct ScanResult {
    public let module: ModuleID
    public var items: [ScanItem]
    public let scannedAt: Date
    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    public var count: Int { items.count }

    public init(module: ModuleID, items: [ScanItem], scannedAt: Date = Date()) {
        self.module = module
        self.items = items
        self.scannedAt = scannedAt
    }
}

public enum ModuleID: String, CaseIterable, Identifiable, Sendable {
    case dashboard, smartScan, cleanup, uninstaller, files, similarPhotos, developer, spaceLens
    case security, privacy
    case updates, performance, maintenance
    case history
    case result

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard:   return L("Vue d'ensemble")
        case .smartScan:   return L("Smart Scan")
        case .cleanup:     return L("Fichiers inutiles")
        case .uninstaller: return L("Désinstalleur")
        case .files:       return L("Volumineux & doublons")
        case .similarPhotos: return L("Photos similaires")
        case .developer:   return L("Développeur")
        case .spaceLens:   return L("Space Lens")
        case .security:    return L("Sécurité")
        case .privacy:     return L("Confidentialité")
        case .updates:     return L("Mises à jour")
        case .performance: return L("Performance")
        case .maintenance: return L("Maintenance")
        case .history:     return L("Historique")
        case .result:      return L("Nettoyage terminé")
        }
    }

    public var subtitle: String {
        switch self {
        case .dashboard:   return L("Santé du Mac")
        case .smartScan:   return L("Scan complet")
        case .cleanup:     return L("Caches, logs, corbeilles")
        case .uninstaller: return L("Apps + résidus")
        case .files:       return L("Gros fichiers & doublons")
        case .similarPhotos: return L("Images quasi identiques")
        case .developer:   return L("Xcode, node_modules, caches")
        case .spaceLens:   return L("Carte interactive du disque")
        case .security:    return L("Anti-malware, FileVault")
        case .privacy:     return L("Cookies, traceurs")
        case .updates:     return L("Apps obsolètes")
        case .performance: return L("Démarrage, agents")
        case .maintenance: return L("Reindex, scripts")
        case .history:     return L("Nettoyages passés")
        case .result:      return L("Récap après nettoyage")
        }
    }

    public var symbol: String {
        switch self {
        case .dashboard:   return "dashboard"
        case .smartScan:   return "scan"
        case .cleanup:     return "broom"
        case .uninstaller: return "app"
        case .files:       return "files"
        case .similarPhotos: return "files"
        case .developer:   return "chip"
        case .spaceLens:   return "disk"
        case .security:    return "shield"
        case .privacy:     return "eye"
        case .updates:     return "arrow"
        case .performance: return "bolt"
        case .maintenance: return "wrench"
        case .history:     return "clock"
        case .result:      return "sparkle"
        }
    }
}

public enum ScanError: Error {
    case cancelled
    case unreadablePath(URL)
}
