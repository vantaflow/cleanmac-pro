# CleanMac Pro — Notes for Claude

## What this is
Native macOS app (Swift + SwiftUI) for disk cleaning. Goal: simple, transparent, fast.

## Layout
- `Sources/CleanCore/` — pure library, no UI. All scanners go here.
- `Sources/CleanMacPro/` — `@main` SwiftUI app, depends on CleanCore.
- `Tests/CleanCoreTests/` — XCTest on fixture trees.

## Adding a new module

1. Add a case to `ModuleID` in `Models.swift` (give it a title, subtitle, SF Symbol).
2. Create a new `XxxScanner: Scanner` in `Sources/CleanCore/Scanners/`.
3. Wire it in `AppState.scanner(for:)`.
4. Add an XCTest case that uses fixture files under `NSTemporaryDirectory()`.

Then give it a sidebar entry / screen in `Shell/IconRail.swift` and `DashboardView.swift` (`ContentPane`).

## Build / test
- `swift build` — must compile.
- `swift test` — must pass.
- `swift run CleanMacPro` — launches the app (requires running on a macOS GUI session, not headless).

## Conventions
- Scanners are pure: they accept a `progress` closure and return a `ScanResult`. No side effects.
- Cleaning goes through `Cleaner.clean(items:)`, which is **policy-aware** (`ItemKind.deletionPolicy`): regenerable kinds (`isRegenerable`: cache, log, tempFile) and the Trash itself are deleted permanently (the Trash would only hide that no space was freed); personal files (largeFile, oldFile, duplicate), browser data and apps go to the Trash (`trashItem`, restorable); every other kind is ignored. `clean(items:forcePermanent:adminFallback:)` adds the admin retry for root-owned items (one prompt) and `forcePermanent` for the Uninstaller (a removed `.app` must not linger in the Trash). `Cleaner.isSafeToRemove` refuses roots and container folders.
- History: `HistoryEntry.records` only lists what went to the Trash; permanent deletions are counted (`permanentCount`) and never get a Restore button.
- Smart Care: `SmartCarePlan` (CleanCore, tested) decides the default selection (regenerable only; personal files, browser data and the Trash start unticked) and `runnableItems` is the single gate between "Lancer" and `Cleaner`. Never add a code path that cleans personal files without the user selecting them.
- The freed space shown to the user is `SpaceMeasure` (volume free space before/after), not the sum of item sizes.
- Duplicates: the first copy of a set is a `.keeper` (never cleanable), so "select all" can't remove every copy.
- UI: all colors / radii / spacing come from `Theme/Tokens.swift` (`Color.canvas/card/cardBorder/text1…`, `Accent` per category, `Space`, `Radius`). Every UI string goes through `L(...)` with fr/en/es/de translations (`Tools/check-localization.py`); interpolated Int values must be written `Int(x)` / `.count` so the key gets `%lld`.
- Bytes are `Int64`. Always format for display with `ByteFormatter.string(_:)`.
- Don't add a new way to enumerate the filesystem — use `FS.enumerate(_:)`.

## Known limits
- The package can't produce a notarized `.app` from CLI alone — open in Xcode for that.
- System Caches at `/Library/Caches` may require admin rights; the scanner just skips unreadable paths.
- The Uninstaller's residue match is substring-based. Keep it conservative.
