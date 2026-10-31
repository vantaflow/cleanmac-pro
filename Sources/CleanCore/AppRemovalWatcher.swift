import Foundation
import CoreServices

/// An app that disappeared and still has files in ~/Library.
public struct AppRemovalEvent: Identifiable, Hashable, @unchecked Sendable {
    public var id: String { bundleID }
    public let appName: String
    public let bundleID: String
    /// Where the bundle lived before it disappeared (the icon may still be cached there).
    public let appPath: String
    public let items: [ScanItem]
    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    public init(appName: String, bundleID: String, appPath: String, items: [ScanItem]) {
        self.appName = appName
        self.bundleID = bundleID
        self.appPath = appPath
        self.items = items
    }
}

/// Pure detection state: remembers which apps were installed (bundle id <-> path)
/// so the id is still known once the bundle is gone, and diffs against disk.
/// Not thread-safe; `AppRemovalWatcher` confines it to one serial queue.
public struct AppRemovalDetector: Sendable {
    public let roots: [URL]
    public let trash: URL
    public private(set) var known: [String: InstalledAppRecord] = [:]   // path -> record
    private var trashSeen: Set<String> = []
    /// Where the index is kept between launches, so an app deleted while
    /// CleanMac Pro was not running is still noticed at the next start.
    public let stateFile: URL?
    /// Apps that disappeared since the index was last saved (filled by `baseline()`).
    public private(set) var removedSinceLastRun: [InstalledAppRecord] = []

    public init(roots: [URL], trash: URL, stateFile: URL? = nil) {
        self.roots = roots
        self.trash = trash
        self.stateFile = stateFile
        baseline()
    }

    /// Snapshot of the current state; nothing already there is ever reported,
    /// except apps the saved index knew and that are gone since (`removedSinceLastRun`).
    public mutating func baseline() {
        let current = AppIndex.build(roots: roots).apps
        known = Dictionary(current.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        trashSeen = Set(trashApps().map { $0.standardizedFileURL.path })
        removedSinceLastRun = []
        if let saved = loadState() {
            let installedIDs = Set(current.map { $0.bundleID.lowercased() })
            removedSinceLastRun = saved.filter {
                known[$0.path] == nil && !FileManager.default.fileExists(atPath: $0.path)
                    && !installedIDs.contains($0.bundleID.lowercased())
            }
        }
        saveState()
    }

    private func loadState() -> [InstalledAppRecord]? {
        guard let stateFile, let data = try? Data(contentsOf: stateFile) else { return nil }
        return try? JSONDecoder().decode([InstalledAppRecord].self, from: data)
    }

    private func saveState() {
        guard let stateFile else { return }
        try? FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Array(known.values)) { try? data.write(to: stateFile, options: .atomic) }
    }

    private func trashApps() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "app" }
    }

    /// Re-reads the disk and returns the apps that left the index for good.
    /// An id still installed elsewhere (moved, or being replaced by an update) is not a removal.
    public mutating func refresh() -> [InstalledAppRecord] {
        let current = AppIndex.build(roots: roots)
        let currentByPath = Dictionary(current.apps.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        let installedIDs = Set(current.apps.map { $0.bundleID.lowercased() })
        var removed: [InstalledAppRecord] = []
        for (path, rec) in known where currentByPath[path] == nil {
            if FileManager.default.fileExists(atPath: path) { continue }   // unreadable, not gone
            if !installedIDs.contains(rec.bundleID.lowercased()) { removed.append(rec) }
        }

        // Apps that landed in the Trash without ever being indexed (e.g. from ~/Downloads).
        let trashNow = trashApps()
        let reported = Set(removed.map { $0.bundleID.lowercased() })
        for u in trashNow where !trashSeen.contains(u.standardizedFileURL.path) {
            guard let rec = AppIndex.record(forApp: u) else { continue }
            let id = rec.bundleID.lowercased()
            if installedIDs.contains(id) || reported.contains(id) { continue }
            removed.append(rec)
        }
        trashSeen = Set(trashNow.map { $0.standardizedFileURL.path })
        known = currentByPath
        saveState()
        return removed
    }

    /// Leftovers of removed apps, exclusions applied; apps with nothing left are dropped.
    public func events(for removed: [InstalledAppRecord],
                       leftovers: AppLeftovers,
                       installed: AppIndex,
                       exclusions: ExclusionList) -> [AppRemovalEvent] {
        var out: [AppRemovalEvent] = []
        for rec in removed {
            if exclusions.appIDs.contains(where: { $0.caseInsensitiveCompare(rec.bundleID) == .orderedSame }) { continue }
            let ids = installed.knownIDs(excluding: rec.bundleID)
            let names = installed.knownNames(excluding: rec.bundleID)
            let items = exclusions.apply(to: leftovers.find(bundleID: rec.bundleID, name: rec.name,
                                                            otherInstalledIDs: ids, otherInstalledNames: names))
            if !items.isEmpty { out.append(AppRemovalEvent(appName: rec.name, bundleID: rec.bundleID, appPath: rec.path, items: items)) }
        }
        return out
    }
}

/// Watches /Applications, ~/Applications and the Trash with FSEvents and reports
/// an app that was removed while files remain in ~/Library.
public final class AppRemovalWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ai.turkeycode.cleanmacpro.app-removal", qos: .utility)
    private var detector: AppRemovalDetector
    private let leftovers: AppLeftovers
    private let settleDelay: TimeInterval
    private let exclusions: @Sendable () -> ExclusionList
    private let onRemoval: @Sendable (AppRemovalEvent) -> Void
    private var stream: FSEventStreamRef?
    private var pending: DispatchWorkItem?

    public init(roots: [URL] = [URL(fileURLWithPath: "/Applications"), FS.home.appendingPathComponent("Applications")],
                trash: URL = FS.home.appendingPathComponent(".Trash"),
                library: URL = FS.home.appendingPathComponent("Library"),
                stateFile: URL? = nil,
                settleDelay: TimeInterval = 3,
                exclusions: @escaping @Sendable () -> ExclusionList = { ExclusionList.load() },
                onRemoval: @escaping @Sendable (AppRemovalEvent) -> Void) {
        self.detector = AppRemovalDetector(roots: roots, trash: trash, stateFile: stateFile)
        self.leftovers = AppLeftovers(library: library)
        self.settleDelay = settleDelay
        self.exclusions = exclusions
        self.onRemoval = onRemoval
    }

    deinit { stop() }

    public func start() {
        queue.async { [self] in
            guard stream == nil else { return }
            detector.baseline()
            report(detector.removedSinceLastRun)
            var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<AppRemovalWatcher>.fromOpaque(info).takeUnretainedValue().changed()
            }
            let paths = (detector.roots + [detector.trash]).map { $0.path } as CFArray
            guard let s = FSEventStreamCreate(nil, callback, &ctx, paths,
                                              FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0,
                                              FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)) else { return }
            FSEventStreamSetDispatchQueue(s, queue)
            FSEventStreamStart(s)
            stream = s
        }
    }

    public func stop() {
        queue.sync {
            pending?.cancel(); pending = nil
            if let s = stream {
                FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s)
                stream = nil
            }
        }
    }

    /// Called on `queue` by FSEvents: waits for the dust to settle (an update swaps the
    /// bundle for a moment) before looking at the disk.
    private func changed() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.process() }
        pending = w
        queue.asyncAfter(deadline: .now() + settleDelay, execute: w)
    }

    /// Synchronous check (also used by tests). Must run on `queue` or before `start()`.
    func process() {
        report(detector.refresh())
    }

    private func report(_ removed: [InstalledAppRecord]) {
        guard !removed.isEmpty else { return }
        let installed = AppIndex.build(roots: detector.roots + AppIndex.defaultRoots, extraIDs: [])
        for ev in detector.events(for: removed, leftovers: leftovers, installed: installed, exclusions: exclusions()) {
            onRemoval(ev)
        }
    }

    /// Test hook: run one detection pass on the watcher's queue and wait for it.
    func processNow() { queue.sync { process() } }
}
