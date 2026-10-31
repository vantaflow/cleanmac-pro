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
        progress(0.0, L("Gros fichiers & anciens…"))
        let largeResult = try await large.scan { p, msg in progress(p * 0.5, msg) }

        progress(0.5, L("Recherche de doublons…"))
        let dupResult = try await duplicates.scan { p, msg in progress(0.5 + p * 0.5, msg) }

        // Merge, de-duplicating by URL so a file that is both large and a
        // duplicate is listed once (keeping the large-file entry) and its
        // size is never double-counted in the module total.
        // A kept original is never offered for cleaning, even if it is also a
        // large file: the keeper entry wins over the large-file entry.
        let keepers = Set(dupResult.items.filter { $0.kind == .keeper }.map(\.url))
        var items = largeResult.items.filter { !keepers.contains($0.url) }
        let seen = Set(items.map(\.url))
        items.append(contentsOf: dupResult.items.filter { !seen.contains($0.url) })

        progress(1.0, L("Done"))
        return ScanResult(module: .files, items: items)
    }
}
