# MacCleaner

A native macOS disk cleanup tool built with Swift and SwiftUI. Scans 27 categories of cleanable files — from Xcode DerivedData to Docker images — and lets you reclaim disk space safely.

![Dashboard](docs/screenshot/Screenshot%202026-04-11%20at%2010.04.51%20AM.png)

The dashboard shows a full breakdown of your disk: an APFS volume chart, a treemap of storage by category, and quick-action buttons for common cleanups.

![Clean All](docs/screenshot/Screenshot%202026-04-11%20at%2010.05.26%20AM.png)

The Clean All dialog offers three tiers — **Quick Clean** (caches and build artifacts), **Deep Clean** (+ old versions and dev tools), and **Expert Clean** (+ app data and Docker images) — so you can choose how aggressive the cleanup should be.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/haiz/maccleaner/main/install.sh | bash
```

> First launch: right-click the app and choose **Open** (macOS Gatekeeper requires this for unsigned apps).

## Features

- **27 scan categories** — Xcode, Homebrew, Docker, Node modules, system caches, logs, simulators, and more
- **Safety levels** — items are marked as *Safe* (auto-regenerating caches) or *Caution* (backups, archives) so you know what you're deleting
- **Treemap visualization** — see exactly where your disk space goes at a glance
- **Three cleanup tiers** — Quick, Deep, and Expert clean for different levels of aggressiveness
- **Moves to Trash** — file-based cleanups go to Trash so you can recover if needed
- **CLI included** — `maccleaner scan`, `maccleaner clean`, `maccleaner list` for terminal workflows
- **Parallel scanning** — uses Swift `TaskGroup` for fast concurrent scans

## Requirements

- macOS 13.0 (Ventura) or later

## Build from Source

```bash
git clone https://github.com/haiz/maccleaner.git
cd maccleaner
swift build -c release --product MacCleanerApp
```

The built binary is at `.build/release/MacCleanerApp`.

### CLI

```bash
swift build -c release --product maccleaner

# Scan for cleanable items
.build/release/maccleaner scan

# Clean specific categories
.build/release/maccleaner clean

# List all categories
.build/release/maccleaner list
```

## Architecture

```
MacCleanerCore   — Reusable library: scanning, cleaning, models
MacCleanerCLI    — Command-line interface (swift-argument-parser)
MacCleanerApp    — SwiftUI GUI with NavigationSplitView layout
```

## License

MIT
