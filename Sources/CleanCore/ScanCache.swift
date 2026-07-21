import Foundation

/// Incremental-scan cache. A scan is reused when it is recent *and* every root
/// directory's modification date is unchanged since it was taken — so a new
/// download or cache write invalidates the relevant module, but back-to-back
/// scans (e.g. the 6 h background agent re-firing, or reopening the popover)
/// return instantly instead of re-walking the tree.
///
/// Limitation by design: a directory's mtime reflects changes to its *direct*
/// entries, not deep descendants, so `maxAge` bounds staleness as a backstop.
public actor ScanCache {
    public static let shared = ScanCache()
    public init() {}

    struct Entry {
        let items: [ScanItem]
        let date: Date
        let fingerprint: [String: TimeInterval]
    }

    private var store: [ModuleID: Entry] = [:]

    /// Snapshot of each root's mtime; missing roots are simply absent.
    public func fingerprint(_ roots: [URL]) -> [String: TimeInterval] {
        var fp: [String: TimeInterval] = [:]
        let fm = FileManager.default
        for r in roots {
            if let attrs = try? fm.attributesOfItem(atPath: r.path),
               let m = attrs[.modificationDate] as? Date {
                fp[r.path] = m.timeIntervalSince1970
            }
        }
        return fp
    }

    /// Returns cached items iff fresh (`< maxAge`) and roots are unchanged.
    public func cached(_ module: ModuleID, roots: [URL], maxAge: TimeInterval, now: Date = Date()) -> [ScanItem]? {
        guard let e = store[module] else { return nil }
        guard now.timeIntervalSince(e.date) < maxAge else { return nil }
        guard e.fingerprint == fingerprint(roots) else { return nil }
        return e.items
    }

    public func save(_ module: ModuleID, roots: [URL], items: [ScanItem], now: Date = Date()) {
        store[module] = Entry(items: items, date: now, fingerprint: fingerprint(roots))
    }

    public func invalidate(_ module: ModuleID? = nil) {
        if let module { store[module] = nil } else { store.removeAll() }
    }
}
