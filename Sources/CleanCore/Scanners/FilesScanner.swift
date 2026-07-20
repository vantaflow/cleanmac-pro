import Foundation

/// The `.files` module the UI actually uses: large files, old files, AND
/// SHA-256-verified duplicates, merged into one result. Previously the app
/// wired only `LargeFilesScanner`, so `DuplicatesScanner` never ran despite
/// the README advertising it.
public struct FilesScanner: FileScanner {
    public let module: ModuleID = .files
    private let large: LargeFilesScanner
    private let duplicates: DuplicatesScanner

    public init(
        large: LargeFilesScanner = LargeFilesScanner(),
        duplicates: DuplicatesScanner = DuplicatesScanner()
    ) {
        self.large = large
        self.duplicates = duplicates
    }

    public func scan(progress: @escaping (Double, String) -> Void) async throws -> ScanResult {
        progress(0.0, "Gros fichiers & anciens…")
        let largeResult = try await large.scan { p, msg in progress(p * 0.5, msg) }

        progress(0.5, "Recherche de doublons…")
        let dupResult = try await duplicates.scan { p, msg in progress(0.5 + p * 0.5, msg) }

        // Merge, de-duplicating by URL so a file that is both large and a
        // duplicate is listed once (keeping the large-file entry) and its
        // size is never double-counted in the module total.
        var items = largeResult.items
        let seen = Set(items.map(\.url))
        items.append(contentsOf: dupResult.items.filter { !seen.contains($0.url) })

        progress(1.0, "Done")
        return ScanResult(module: .files, items: items)
    }
}
