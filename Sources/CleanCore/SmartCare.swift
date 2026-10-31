import Foundation

/// The five cards of the Smart Care results screen.
public enum SmartCareCategory: String, CaseIterable, Identifiable, Sendable {
    case cleanup, protection, performance, applications, clutter
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cleanup:      return L("Nettoyage")
        case .protection:   return L("Protection")
        case .performance:  return L("Performances")
        case .applications: return L("Applications")
        case .clutter:      return L("Encombrement")
        }
    }

    /// Module opened by the "Revoir" button of the card.
    public var reviewModule: ModuleID {
        switch self {
        case .cleanup:      return .cleanup
        case .protection:   return .security
        case .performance:  return .performance
        case .applications: return .updates
        case .clutter:      return .files
        }
    }
}

/// Pure decision logic of Smart Care (no UI, no I/O): what the scan found, what
/// is selected by default, and — most importantly — what "Lancer" is allowed to
/// touch.
///
/// Safety contract, enforced by `runnableItems` and covered by tests:
/// - regenerable data (caches, logs, temp files, developer caches) is selected
///   by default; the Trash only if the user ticked it;
/// - personal files (large / old / duplicates / similar photos), browser data
///   and anything else are **never** selected by default; they run only when the
///   user selected them himself in the review screen of their module.
public struct SmartCarePlan {
    /// Modules whose items can be cleaned from Smart Care.
    public static let cleanableModules: [ModuleID] = [.cleanup, .developer, .files, .similarPhotos, .privacy]

    public let results: [ModuleID: ScanResult]
    public let selections: [ModuleID: Set<UUID>]

    public init(results: [ModuleID: ScanResult], selections: [ModuleID: Set<UUID>]) {
        self.results = results
        self.selections = selections
    }

    private func items(_ m: ModuleID) -> [ScanItem] { results[m]?.items ?? [] }
    private func selected(_ m: ModuleID) -> Set<UUID> { selections[m] ?? [] }
    private static func sum(_ xs: [ScanItem]) -> Int64 { xs.reduce(0) { $0 + $1.size } }

    // MARK: Default selection

    /// What is ticked right after a scan. Only regenerable items; everything
    /// else (personal files, browser data, the Trash) starts unticked.
    public static func defaultSelection(for module: ModuleID, items: [ScanItem]) -> Set<UUID> {
        guard module == .cleanup || module == .developer else { return [] }
        return Set(items.filter { $0.kind.isRegenerable }.map(\.id))
    }

    // MARK: Cleanup card

    /// Caches / logs / temp files from the cleanup and developer scans.
    public var regenerableItems: [ScanItem] {
        (items(.cleanup) + items(.developer)).filter { $0.kind.isRegenerable }
    }
    public var regenerableBytes: Int64 { Self.sum(regenerableItems) }
    public var selectedRegenerable: [ScanItem] {
        let s = selected(.cleanup).union(selected(.developer))
        return regenerableItems.filter { s.contains($0.id) }
    }
    public var selectedRegenerableBytes: Int64 { Self.sum(selectedRegenerable) }

    public var trashItems: [ScanItem] { items(.cleanup).filter { $0.kind == .trash } }
    public var trashBytes: Int64 { Self.sum(trashItems) }
    public var selectedTrash: [ScanItem] {
        let s = selected(.cleanup)
        return trashItems.filter { s.contains($0.id) }
    }
    public var trashSelected: Bool { !trashItems.isEmpty && selectedTrash.count == trashItems.count }

    /// Bytes per category label (caches, temp, logs, developer…), for the card summary.
    public func regenerableBytes(kind: ItemKind, module: ModuleID? = nil) -> Int64 {
        let pool = module.map { items($0) } ?? (items(.cleanup) + items(.developer))
        return Self.sum(pool.filter { $0.kind == kind })
    }
    public var developerCacheBytes: Int64 { Self.sum(items(.developer).filter { $0.kind.isRegenerable }) }

    // MARK: Protection card

    public var securityIssues: [ScanItem] {
        items(.security).filter { $0.kind == .securityFinding && ($0.severity == .warn || $0.severity == .bad) }
    }
    /// Known-malware persistence hits (the `Menaces` group, severity bad).
    public var threats: [ScanItem] {
        securityIssues.filter { $0.group == L("Menaces") && $0.severity == .bad }
    }
    public var settingsToCheck: [ScanItem] { securityIssues.filter { $0.group != L("Menaces") } }
    public var privacyItems: [ScanItem] { items(.privacy).filter { $0.kind == .privacyData } }
    public var privacyBytes: Int64 { Self.sum(privacyItems) }
    public var selectedPrivacy: [ScanItem] {
        let s = selected(.privacy)
        return privacyItems.filter { s.contains($0.id) }
    }

    // MARK: Performance card

    /// Login items / launch agents that can be switched off, plus very heavy processes.
    public var performanceTasks: [ScanItem] {
        items(.performance).filter {
            (($0.kind == .loginItem || $0.kind == .launchAgent) && $0.command != nil)
            || ($0.kind == .processSnapshot && $0.severity == .warn)
        }
    }

    // MARK: Applications card

    public var updates: [ScanItem] {
        items(.updates).filter { $0.kind == .updateAvailable && ($0.severity == .warn || $0.severity == .bad) }
    }
    /// Updates Smart Care can install by itself (verified Sparkle releases).
    public var installableUpdates: [ScanItem] { updates.filter { $0.sparkleRelease != nil } }

    // MARK: Clutter card

    /// Large / old files, duplicates and similar photos: reviewed by hand only.
    public var clutterItems: [ScanItem] {
        (items(.files) + items(.similarPhotos)).filter { $0.kind.isPersonalFile }
    }
    public var clutterBytes: Int64 { Self.sum(clutterItems) }
    public var selectedClutter: [ScanItem] {
        let s = selected(.files).union(selected(.similarPhotos))
        return clutterItems.filter { s.contains($0.id) }
    }

    // MARK: What "Lancer" runs

    /// The single gate between the UI and `Cleaner`: items that are selected,
    /// still cleanable, and belong to a Smart Care module. Because only
    /// regenerable items are selected by default, a plan nobody reviewed never
    /// contains a personal file.
    public var runnableItems: [ScanItem] {
        var seen = Set<URL>()
        var out: [ScanItem] = []
        for m in Self.cleanableModules {
            let sel = selected(m)
            for it in items(m) where sel.contains(it.id) && it.kind.isCleanable && seen.insert(it.url).inserted {
                out.append(it)
            }
        }
        return out
    }

    public var runnableBytes: Int64 { Self.sum(runnableItems) }
    /// Part of the run that frees space immediately (permanent deletions).
    public var runnablePermanentBytes: Int64 {
        Self.sum(runnableItems.filter { $0.kind.deletionPolicy == .permanent })
    }
    /// Part of the run that lands in the Trash (frees nothing until it is emptied).
    public var runnableTrashBytes: Int64 {
        Self.sum(runnableItems.filter { $0.kind.deletionPolicy == .trash })
    }
    public var hasWork: Bool { !runnableItems.isEmpty }
}
