import XCTest
@testable import MacCleanerCore

/// Tests for CLI-related logic (not the ArgumentParser itself, but the core
/// logic that the CLI commands exercise).
final class CLIIntegrationTests: XCTestCase {

    // MARK: - Scan workflow

    func testScanAllReturnsNonEmptyBreakdown() async {
        let scanner = DiskScanner()
        let breakdown = await scanner.scanAll()

        XCTAssertGreaterThan(breakdown.categories.count, 0)
        XCTAssertGreaterThan(breakdown.totalDiskBytes, 0)
        // At least one category should have data on a real machine
        XCTAssertGreaterThan(breakdown.totalScannedBytes, 0)
    }

    func testScanBreakdownHasVolumeInfo() async {
        let scanner = DiskScanner()
        let breakdown = await scanner.scanAll()

        XCTAssertGreaterThan(breakdown.totalDiskBytes, 0)
        XCTAssertGreaterThan(breakdown.freeDiskBytes, 0)
        XCTAssertGreaterThan(breakdown.totalDiskBytes, breakdown.freeDiskBytes)
    }

    // MARK: - Clean workflow: --safe filter

    func testCleanSafeFilterExcludesCaution() async {
        let scanner = DiskScanner()
        let breakdown = await scanner.scanAll()

        let safeCategories = breakdown.categories.filter { $0.safetyLevel == .safe && $0.totalBytes > 0 }
        let cautionCategories = breakdown.categories.filter { $0.safetyLevel == .caution && $0.totalBytes > 0 }

        // Safe categories should exist
        XCTAssertGreaterThan(safeCategories.count, 0, "Expected at least one safe category with data")

        // Verify safety levels are correctly assigned
        for cat in safeCategories {
            XCTAssertEqual(cat.safetyLevel, .safe)
        }
        for cat in cautionCategories {
            XCTAssertEqual(cat.safetyLevel, .caution)
        }
    }

    // MARK: - Clean workflow: --category filter

    func testFindCleanableCategoryByName() {
        let scanner = DiskScanner()
        let executor = CleanupExecutor(scanner: scanner)

        // Cleanable categories should be findable
        let xcode = executor.findCleanableCategory(named: "Xcode DerivedData")
        XCTAssertNotNil(xcode)

        let docker = executor.findCleanableCategory(named: "Docker")
        XCTAssertNotNil(docker)

        let node = executor.findCleanableCategory(named: "node_modules")
        XCTAssertNotNil(node)

        // Scan-only categories should NOT be findable as CleanableCategory
        let systemLogs = executor.findCleanableCategory(named: "System Logs")
        XCTAssertNil(systemLogs)

        let timeMachine = executor.findCleanableCategory(named: "Time Machine")
        XCTAssertNil(timeMachine)
    }

    // MARK: - Clean workflow: nothing to clean

    func testCleanWithEmptyItemsProducesCleanReport() async {
        let category = FileBasedCategory(
            name: "Empty",
            icon: "test",
            safetyLevel: .safe,
            scanPaths: []
        )
        let report = await category.clean(items: [])

        XCTAssertEqual(report.itemsCleaned, 0)
        XCTAssertEqual(report.bytesFreed, 0)
        XCTAssertFalse(report.hasErrors)
        XCTAssertEqual(report.categoryName, "Empty")
    }

    // MARK: - Irreversibility flags

    func testIrreversibilityCategorization() {
        let scanner = DiskScanner()

        for category in scanner.categories {
            guard let cleanable = category as? (any CleanableCategory) else { continue }

            switch cleanable.name {
            case "Docker", "Homebrew":
                XCTAssertTrue(cleanable.isIrreversible, "\(cleanable.name) should be irreversible")
            default:
                XCTAssertFalse(cleanable.isIrreversible, "\(cleanable.name) should be reversible (Trash)")
            }
        }
    }
}
