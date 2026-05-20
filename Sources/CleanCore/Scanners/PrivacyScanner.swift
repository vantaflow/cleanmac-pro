import Foundation

/// Per-browser browsing data — cookies, caches, history files. Each path
/// becomes a real ScanItem with its actual URL, so the Cleaner can move it
/// to the Trash.
public struct PrivacyScanner: FileScanner {
    public let module: ModuleID = .privacy

    public init() {}

    private struct PrivacyTarget {
        let label: String      // "Cookies", "Cache", "Historique"
        let path: String       // tilde-expandable path
    }

    private struct BrowserSpec {
        let name: String
        let targets: [PrivacyTarget]
    }

    private var browsers: [BrowserSpec] {
        [
            .init(name: "Safari", targets: [
                .init(label: "Historique",            path: "~/Library/Safari/History.db"),
                .init(label: "Téléchargements",       path: "~/Library/Safari/Downloads.plist"),
                .init(label: "Cache",                 path: "~/Library/Caches/com.apple.Safari"),
                .init(label: "Cookies",               path: "~/Library/Cookies/Cookies.binarycookies"),
            ]),
            .init(name: "Chrome", targets: [
                .init(label: "Cookies",               path: "~/Library/Application Support/Google/Chrome/Default/Cookies"),
                .init(label: "Historique",            path: "~/Library/Application Support/Google/Chrome/Default/History"),
                .init(label: "Cache profil",          path: "~/Library/Application Support/Google/Chrome/Default/Cache"),
                .init(label: "Cache global",          path: "~/Library/Caches/Google/Chrome"),
            ]),
            .init(name: "Firefox", targets: [
                .init(label: "Profils",               path: "~/Library/Application Support/Firefox/Profiles"),
                .init(label: "Cache",                 path: "~/Library/Caches/Firefox"),
            ]),
            .init(name: "Brave", targets: [
                .init(label: "Cookies",               path: "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies"),
                .init(label: "Cache",                 path: "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache"),
            ]),
            .init(name: "Arc", targets: [
                .init(label: "Données",               path: "~/Library/Application Support/Arc"),
                .init(label: "Cache",                 path: "~/Library/Caches/Company.ThePersistantNonsenseUnknownInc.Arc"),
            ]),
        ]
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        var items: [ScanItem] = []
        let total = Double(browsers.count)

        for (idx, browser) in browsers.enumerated() {
            progress(Double(idx) / total, "Analyse \(browser.name)…")
            for target in browser.targets {
                let url = FS.expand(target.path)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                let size = isDir.boolValue ? FS.directorySize(url) : FS.size(of: url)
                guard size > 0 else { continue }

                items.append(ScanItem(
                    url: url,
                    size: size,
                    modified: FS.modified(of: url),
                    kind: .privacyData,
                    group: browser.name,
                    title: target.label,
                    detail: url.path,
                    severity: size > 200_000_000 ? .warn : .info
                ))
            }
        }
        progress(1.0, "Done")
        return ScanResult(module: .privacy, items: items)
    }
}
