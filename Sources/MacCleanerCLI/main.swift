import ArgumentParser
import Foundation
import MacCleanerCore

@main
struct MacCleanerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maccleaner",
        abstract: "macOS storage intelligence tool — scan and clean disk bloat.",
        subcommands: [Scan.self, List.self, Clean.self],
        defaultSubcommand: Scan.self
    )
}

// MARK: - Scan Command

struct Scan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scan disk and show storage breakdown."
    )

    @Option(name: .long, help: "Scan a specific category only.")
    var category: String?

    func run() async throws {
        let scanner = DiskScanner()

        print("\u{001B}[1m\u{001B}[36m● Scanning Macintosh HD...\u{001B}[0m")
        print()

        let breakdown = await scanner.scanAll()

        // Volume info
        let totalStr = ByteCountFormatter.string(fromByteCount: breakdown.totalDiskBytes, countStyle: .file)
        let freeStr = ByteCountFormatter.string(fromByteCount: breakdown.freeDiskBytes, countStyle: .file)
        let usedPct = breakdown.totalDiskBytes > 0
            ? Double(breakdown.totalDiskBytes - breakdown.freeDiskBytes) / Double(breakdown.totalDiskBytes) * 100
            : 0

        print("  Storage: \(totalStr) total, \u{001B}[31m\(freeStr) free (\(String(format: "%.1f", 100 - usedPct))%)\u{001B}[0m")

        // Progress bar
        let barWidth = 30
        let filledCount = Int(usedPct / 100 * Double(barWidth))
        let bar = String(repeating: "█", count: filledCount) + String(repeating: "░", count: barWidth - filledCount)
        print("  \u{001B}[31m\(bar)\u{001B}[0m \(String(format: "%.1f", usedPct))% used")
        print()

        // Category breakdown
        print("  \u{001B}[1mCategory Breakdown:\u{001B}[0m")
        for cat in breakdown.nonEmptyCategories {
            if let filterName = category, cat.categoryName != filterName { continue }

            let sizeStr = ByteCountFormatter.string(fromByteCount: cat.totalBytes, countStyle: .file)
            let maxBarWidth = 20
            let catPct = breakdown.totalScannedBytes > 0
                ? Double(cat.totalBytes) / Double(breakdown.totalScannedBytes)
                : 0
            let catBar = String(repeating: "█", count: max(1, Int(catPct * Double(maxBarWidth))))

            let reclaimNote: String
            if let reclaimable = cat.reclaimableBytes {
                let reclStr = ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .file)
                reclaimNote = " (\(reclStr) reclaimable)"
            } else {
                reclaimNote = ""
            }

            let safetyColor = cat.safetyLevel == .safe ? "\u{001B}[32m" : "\u{001B}[33m"
            let errorNote = cat.error != nil ? " \u{001B}[33m⚠\u{001B}[0m" : ""

            let nameStr = cat.categoryName.padding(toLength: 22, withPad: " ", startingAt: 0)
            print("    \(nameStr) \(safetyColor)\(sizeStr)\u{001B}[0m  \(catBar)\(reclaimNote)\(errorNote)")
        }

        print()
        let totalScanned = ByteCountFormatter.string(fromByteCount: breakdown.totalScannedBytes, countStyle: .file)
        let totalReclaimable = ByteCountFormatter.string(fromByteCount: breakdown.totalReclaimableBytes, countStyle: .file)
        print("  \u{001B}[32m✓ Total scanned: \(totalScanned) | Reclaimable: \(totalReclaimable)\u{001B}[0m")
        print()
    }
}

// MARK: - Clean Command

struct Clean: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clean safe items or a specific category."
    )

    @Flag(name: .long, help: "Clean all items with SafetyLevel.safe. Caution items require --category.")
    var safe = false

    @Option(name: .long, help: "Clean a specific category by name.")
    var category: String?

    @Flag(name: .long, help: "Skip confirmation prompt.")
    var yes = false

    func validate() throws {
        guard safe || category != nil else {
            throw ValidationError("Specify --safe to clean all safe items, or --category <name> to target one.")
        }
    }

    func run() async throws {
        let scanner = DiskScanner()
        let executor = CleanupExecutor(scanner: scanner)

        // Scan first
        print("\u{001B}[1m\u{001B}[36m● Scanning...\u{001B}[0m")
        let breakdown = await scanner.scanAll()

        // Collect targets
        var targets: [(category: any CleanableCategory, items: [CleanableItem])] = []

        for result in breakdown.nonEmptyCategories {
            // Filter by category name if specified
            if let filterName = category, result.categoryName != filterName { continue }

            // Filter by safety level if --safe
            if safe && result.safetyLevel != .safe { continue }

            // Find the CleanableCategory instance
            guard let cleanable = executor.findCleanableCategory(named: result.categoryName) else {
                continue // scan-only category
            }

            let items = result.items.filter { item in
                if safe { return item.safetyLevel == .safe }
                return true
            }

            if !items.isEmpty {
                targets.append((cleanable, items))
            }
        }

        if targets.isEmpty {
            print("\n  \u{001B}[33mNothing to clean.\u{001B}[0m")
            if safe {
                print("  No safe items found. Try --category <name> for specific categories.")
            }
            print()
            return
        }

        // Show what will be cleaned
        print()
        print("  \u{001B}[1mItems to clean:\u{001B}[0m")
        var totalBytesToFree: Int64 = 0
        for (cat, items) in targets {
            let size = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
            totalBytesToFree += size
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let irreversibleNote = cat.isIrreversible ? " \u{001B}[33m(irreversible)\u{001B}[0m" : " (→ Trash)"
            print("    \(cat.name.padding(toLength: 22, withPad: " ", startingAt: 0)) \u{001B}[31m\(sizeStr)\u{001B}[0m\(irreversibleNote)")
        }
        let totalStr = ByteCountFormatter.string(fromByteCount: totalBytesToFree, countStyle: .file)
        print()
        print("  Total: \u{001B}[1m\u{001B}[31m\(totalStr)\u{001B}[0m will be freed")
        print()

        // Confirmation
        if !yes {
            print("  Proceed? [y/N] ", terminator: "")
            guard let input = readLine()?.lowercased(), input == "y" || input == "yes" else {
                print("  Cancelled.")
                return
            }
        }

        // Execute cleanup
        print()
        print("  \u{001B}[1mCleaning...\u{001B}[0m")
        var totalFreed: Int64 = 0
        var totalErrors = 0

        for (cat, items) in targets {
            let (report, _) = await executor.cleanAndRescan(category: cat, items: items)

            let freedStr = ByteCountFormatter.string(fromByteCount: report.bytesFreed, countStyle: .file)
            if report.hasErrors {
                print("    \u{001B}[33m⚠\u{001B}[0m \(cat.name.padding(toLength: 22, withPad: " ", startingAt: 0)) \(freedStr) freed (\(report.errors.count) error(s))")
                totalErrors += report.errors.count
            } else {
                print("    \u{001B}[32m✓\u{001B}[0m \(cat.name.padding(toLength: 22, withPad: " ", startingAt: 0)) \(freedStr) freed")
            }
            totalFreed += report.bytesFreed
        }

        let totalFreedStr = ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file)
        print()
        if totalErrors > 0 {
            print("  \u{001B}[33m⚠ Done. \(totalFreedStr) freed with \(totalErrors) error(s).\u{001B}[0m")
        } else {
            print("  \u{001B}[32m✓ Done! \(totalFreedStr) freed.\u{001B}[0m")
        }
        print()
    }
}

// MARK: - List Command

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all available categories."
    )

    func run() async throws {
        let scanner = DiskScanner()

        print("\u{001B}[1mAvailable categories:\u{001B}[0m")
        print()
        for category in scanner.categories {
            let safetyStr = category.safetyLevel == .safe ? "\u{001B}[32mSafe\u{001B}[0m" : "\u{001B}[33mCaution\u{001B}[0m"
            print("  \(category.name.padding(toLength: 22, withPad: " ", startingAt: 0)) [\(safetyStr)]")
        }
        print()
    }
}
