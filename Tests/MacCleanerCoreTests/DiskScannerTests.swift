import XCTest
@testable import MacCleanerCore

final class DiskScannerTests: XCTestCase {

    func testScanAllReturnsAllCategories() async {
        let scanner = DiskScanner()
        let breakdown = await scanner.scanAll()

        // Should have results for all 17 categories
        XCTAssertEqual(breakdown.categories.count, 27)
        XCTAssertGreaterThan(breakdown.totalDiskBytes, 0)
        XCTAssertGreaterThanOrEqual(breakdown.freeDiskBytes, 0)
    }

    func testScanProgressivelyStreamsResults() async {
        let scanner = DiskScanner()
        var count = 0

        for await _ in scanner.scanProgressively() {
            count += 1
        }

        XCTAssertEqual(count, 27)
    }

    func testScanWithCustomCategories() async {
        let scanner = DiskScanner(categories: [
            FileBasedCategory(
                name: "Test",
                icon: "test",
                safetyLevel: .safe,
                scanPaths: [NSTemporaryDirectory()]
            )
        ])

        let breakdown = await scanner.scanAll()
        XCTAssertEqual(breakdown.categories.count, 1)
        XCTAssertEqual(breakdown.categories.first?.categoryName, "Test")
    }

    func testRescanCategory() async {
        let scanner = DiskScanner()
        let result = await scanner.rescanCategory(named: "App Caches")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.categoryName, "App Caches")
    }

    func testRescanNonExistentCategory() async {
        let scanner = DiskScanner()
        let result = await scanner.rescanCategory(named: "NonExistent")

        XCTAssertNil(result)
    }

    func testScanCancellation() async {
        let scanner = DiskScanner()

        let task = Task {
            var count = 0
            for await _ in scanner.scanProgressively() {
                count += 1
                if count >= 2 {
                    break // Simulate cancellation by breaking early
                }
            }
            return count
        }

        let count = await task.value
        XCTAssertGreaterThanOrEqual(count, 2)
        XCTAssertLessThanOrEqual(count, 27) // Should not exceed total categories
    }

    // MARK: - CleanupExecutor

    func testCleanupExecutorFindCategory() {
        let scanner = DiskScanner()
        let executor = CleanupExecutor(scanner: scanner)

        let found = executor.findCleanableCategory(named: "App Caches")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "App Caches")

        let notFound = executor.findCleanableCategory(named: "System Logs")
        XCTAssertNil(notFound) // SystemLogs is scan-only, not CleanableCategory
    }
}
