import Foundation

/// Browsing data that browsers store locally — cookies, caches, history.
/// Each browser entry is returned as one ScanItem so the UI can show them
/// per-browser with a toggle.
public struct PrivacyScanner: FileScanner {
    public let module: ModuleID = .privacy

    public init() {}

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        let browsers: [(String, [String])] = [
            ("Safari", [
                "~/Library/Safari/History.db",
                "~/Library/Safari/Downloads.plist",
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Cookies/Cookies.binarycookies",
            ]),
            ("Chrome", [
                "~/Library/Application Support/Google/Chrome/Default/Cookies",
                "~/Library/Application Support/Google/Chrome/Default/History",
                "~/Library/Application Support/Google/Chrome/Default/Cache",
                "~/Library/Caches/Google/Chrome",
            ]),
            ("Firefox", [
                "~/Library/Application Support/Firefox/Profiles",
                "~/Library/Caches/Firefox",
            ]),
            ("Brave", [
                "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies",
                "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache",
            ]),
            ("Arc", [
                "~/Library/Application Support/Arc",
                "~/Library/Caches/Company.ThePersistantNonsenseUnknownInc.Arc",
            ]),
        ]
        var items: [ScanItem] = []
        let total = Double(browsers.count)

        for (idx, (name, paths)) in browsers.enumerated() {
            progress(Double(idx) / total, "Analyse \(name)…")
            var size: Int64 = 0
            var present = false
            for raw in paths {
                let url = FS.expand(raw)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                present = true
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                size += isDir.boolValue ? FS.directorySize(url) : FS.size(of: url)
            }
            if present {
                items.append(ScanItem(
                    url: URL(fileURLWithPath: "/Browsers/\(name)"),
                    size: size,
                    kind: .privacyData,
                    group: name,
                    title: "Cookies, cache, historique",
                    detail: paths.joined(separator: " · "),
                    severity: size > 200_000_000 ? .warn : .info
                ))
            }
        }
        progress(1.0, "Done")
        return ScanResult(module: .privacy, items: items)
    }
}
