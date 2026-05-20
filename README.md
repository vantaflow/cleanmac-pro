# CleanMac Pro

A leaner, faster, more transparent alternative to CleanMyMac — built in **Swift + SwiftUI** with a focus on a clean dashboard interface and zero hand-waving about what it deletes.

## Why?

- **Transparent**: Every file is shown with its full path and size before anything is touched.
- **Safe**: Cleaning moves items to the Trash, never `rm -rf`.
- **Fast**: Native Swift with concurrent scanning. No Electron, no daemon, no upsell modals.
- **Simple UI**: One sidebar, one module per concern, one big action button.

## Features (v1.0)

| Module             | What it does                                                       |
|--------------------|--------------------------------------------------------------------|
| **Smart Scan**     | Cleans user/system caches, logs, trash, temp dirs                  |
| **Large & Old**    | Finds files ≥ 50 MB or older than 180 days in your usual folders   |
| **Uninstaller**    | Lists apps + their residues (Application Support, Caches, Prefs…)  |
| **Duplicates**     | Detects byte-identical files by size group + SHA-256 verification  |

## Architecture

```
Sources/
├── CleanCore/           # Library — all scanners + cleaning logic (no UI deps)
│   ├── Models.swift     # ScanItem, ScanResult, ModuleID
│   ├── Scanner.swift    # Scanner protocol + Cleaner
│   ├── FileSystem.swift # FS enumeration + ByteFormatter
│   └── Scanners/        # SmartScanner, LargeFilesScanner, AppUninstaller, DuplicatesScanner
└── CleanMacPro/         # Executable — SwiftUI app
    ├── App.swift
    ├── AppState.swift
    └── DashboardView.swift

Tests/CleanCoreTests/    # XCTest — fixture-based scanner tests
```

Scanners conform to a single `Scanner` protocol so the UI treats every module the same way.

## Build & Run

Requires Swift 5.9+ (ships with Xcode 15 or macOS Command Line Tools).

```bash
swift build -c release
swift run CleanMacPro
```

Or open the package in Xcode:

```bash
open Package.swift
```

## Test

```bash
swift test
```

Tests run scanners against ephemeral fixture trees in `NSTemporaryDirectory` — no real user data is touched.

## Safety Notes

- `Cleaner.clean(items:)` uses `FileManager.trashItem(at:resultingItemURL:)`. Restoring is one click in Finder.
- The Uninstaller's residue matching is **conservative**: it matches the bundle ID and the app name as substrings of `~/Library` entries. Review the list before cleaning.
- The Duplicates module always marks the **first** member of a hash group as `keep`. You still pick what to delete.

## Roadmap

- [ ] Auto-detect cleanable apps from `lsof` / launchd before scanning
- [ ] Real-time RAM / CPU / Disk dashboard module
- [ ] Schedule scans (LaunchAgent)
- [ ] Localization (FR / ES / DE)
- [ ] Code signing + notarization pipeline
