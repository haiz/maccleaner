# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build                          # Build all targets
swift build --product maccleaner     # Build CLI only
swift build --product MacCleanerApp  # Build GUI only

# Run
swift run maccleaner scan            # Scan for cleanable items
swift run maccleaner clean           # Clean items
swift run maccleaner list            # List categories
swift run MacCleanerApp              # Launch GUI

# Test
swift test                           # Run all tests
swift test --filter DiskScannerTests # Run a specific test class
```

## Architecture

The project has three targets with a clean separation of concerns:

- **MacCleanerCore** — Reusable library; all scanning/cleaning logic lives here
- **MacCleanerCLI** — Thin wrapper around Core using `swift-argument-parser`
- **MacCleanerApp** — SwiftUI app using `NavigationSplitView` with sidebar + detail layout

### Core Layer (`Sources/MacCleanerCore/`)

**Category System** — Protocol-based and extensible:
- `ScannableCategory` protocol — scan-only (e.g., System Logs)
- `CleanableCategory: ScannableCategory` protocol — can also delete
- `FileBasedCategory` — concrete base class for 23 of the 27 categories; handles file enumeration and trash deletion
- Docker, Homebrew, and Node have custom implementations that shell out to package managers

**DiskScanner** — Orchestrates scanning across all 27 default categories using `TaskGroup` for parallelism. Also exposes an `AsyncStream` API for progressive/streaming results in the GUI.

**CleanupExecutor** — Accepts category names, locates matching categories, deletes items (to Trash or via commands), and rescans to confirm.

**Models:**
- `CleanableItem` — file/dir path + size + `SafetyLevel` (`.safe` or `.caution`)
- `ScanResult` — per-category outcome
- `StorageBreakdown` — aggregated disk snapshot with per-category results
- `CleanupReport` — results of a cleanup run

### Safety Levels

- `.safe` — auto-regenerating artifacts (caches, build output); safe to delete
- `.caution` — backups, simulators, archives; warn before deleting

### GUI Layer (`Sources/MacCleanerApp/`)

- `DashboardViewModel` — `@Observable` class, owns scan state, drives sidebar selection
- Views: Dashboard (overview), Detail (per-category list), Treemap (visualization), Onboarding
- Uses AppKit for dock icon and app lifecycle alongside SwiftUI

## Adding a New Category

1. Create a new file in `Sources/MacCleanerCore/Categories/`
2. Subclass `FileBasedCategory` (or implement `CleanableCategory` directly for command-based tools)
3. Register it in `DiskScanner.defaultCategories` in `DiskScanner.swift`
4. Add test coverage in `Tests/MacCleanerCoreTests/CategoryTests.swift`
