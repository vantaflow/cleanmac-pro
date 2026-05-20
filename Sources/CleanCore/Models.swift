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
        needsAdmin: Bool = false
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
    case dashboard, smartScan, cleanup, uninstaller, files, spaceLens
    case security, privacy
    case updates, performance, maintenance
    case result

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard:   return "Vue d'ensemble"
        case .smartScan:   return "Smart Scan"
        case .cleanup:     return "Fichiers inutiles"
        case .uninstaller: return "Désinstalleur"
        case .files:       return "Volumineux & doublons"
        case .spaceLens:   return "Space Lens"
        case .security:    return "Sécurité"
        case .privacy:     return "Confidentialité"
        case .updates:     return "Mises à jour"
        case .performance: return "Performance"
        case .maintenance: return "Maintenance"
        case .result:      return "Nettoyage terminé"
        }
    }

    public var subtitle: String {
        switch self {
        case .dashboard:   return "Santé du Mac"
        case .smartScan:   return "Scan complet"
        case .cleanup:     return "Caches, logs, corbeilles"
        case .uninstaller: return "Apps + résidus"
        case .files:       return "Gros fichiers & doublons"
        case .spaceLens:   return "Carte interactive du disque"
        case .security:    return "Anti-malware, FileVault"
        case .privacy:     return "Cookies, traceurs"
        case .updates:     return "Apps obsolètes"
        case .performance: return "Démarrage, agents"
        case .maintenance: return "Reindex, scripts"
        case .result:      return "Récap après nettoyage"
        }
    }

    public var symbol: String {
        switch self {
        case .dashboard:   return "dashboard"
        case .smartScan:   return "scan"
        case .cleanup:     return "broom"
        case .uninstaller: return "app"
        case .files:       return "files"
        case .spaceLens:   return "disk"
        case .security:    return "shield"
        case .privacy:     return "eye"
        case .updates:     return "arrow"
        case .performance: return "bolt"
        case .maintenance: return "wrench"
        case .result:      return "sparkle"
        }
    }
}

public enum ScanError: Error {
    case cancelled
    case unreadablePath(URL)
}
