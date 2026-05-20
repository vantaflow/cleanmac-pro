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

The UI auto-renders every module via `ModuleID.allCases` — no view changes needed.

## Build / test
- `swift build` — must compile.
- `swift test` — must pass.
- `swift run CleanMacPro` — launches the app (requires running on a macOS GUI session, not headless).

## Conventions
- Scanners are pure: they accept a `progress` closure and return a `ScanResult`. No side effects.
- All deletion goes through `Cleaner.clean(items:)`, which uses `trashItem`. Never `removeItem`.
- Bytes are `Int64`. Always format for display with `ByteFormatter.string(_:)`.
- Don't add a new way to enumerate the filesystem — use `FS.enumerate(_:)`.

## Known limits
- The package can't produce a notarized `.app` from CLI alone — open in Xcode for that.
- System Caches at `/Library/Caches` may require admin rights; the scanner just skips unreadable paths.
- The Uninstaller's residue match is substring-based. Keep it conservative.
