import Foundation

public struct ScanItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let size: Int64
    public let modified: Date
    public let kind: ItemKind
    public let group: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        size: Int64,
        modified: Date = Date(),
        kind: ItemKind,
        group: String? = nil
    ) {
        self.id = id
        self.url = url
        self.size = size
        self.modified = modified
        self.kind = kind
        self.group = group
    }

    public var name: String { url.lastPathComponent }
}

public enum ItemKind: String, Hashable {
    case cache, log, trash, tempFile
    case largeFile, oldFile
    case app, appResidue
    case duplicate
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
    case smartScan, largeFiles, uninstaller, duplicates
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .largeFiles: return "Large & Old Files"
        case .uninstaller: return "Uninstaller"
        case .duplicates: return "Duplicates"
        }
    }

    public var subtitle: String {
        switch self {
        case .smartScan: return "Caches, logs, trash"
        case .largeFiles: return "Free disk space fast"
        case .uninstaller: return "Remove apps cleanly"
        case .duplicates: return "Find redundant files"
        }
    }

    public var symbol: String {
        switch self {
        case .smartScan: return "sparkles"
        case .largeFiles: return "doc.zipper"
        case .uninstaller: return "trash.square"
        case .duplicates: return "doc.on.doc"
        }
    }
}

public enum ScanError: Error {
    case cancelled
    case unreadablePath(URL)
}
