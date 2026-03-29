import XCTest
@testable import MacCleanerCore

final class ModelsTests: XCTestCase {

    // MARK: - SafetyLevel

    func testSafetyLevelCodable() throws {
        let safe = SafetyLevel.safe
        let data = try JSONEncoder().encode(safe)
        let decoded = try JSONDecoder().decode(SafetyLevel.self, from: data)
        XCTAssertEqual(decoded, .safe)

        let caution = SafetyLevel.caution
        let data2 = try JSONEncoder().encode(caution)
        let decoded2 = try JSONDecoder().decode(SafetyLevel.self, from: data2)
        XCTAssertEqual(decoded2, .caution)
    }

    // MARK: - CleanableItem

    func testCleanableItemFormattedSize() {
        let item = CleanableItem(
            path: "/tmp/test",
            sizeBytes: 1_073_741_824, // 1 GB
            safetyLevel: .safe
        )
        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertTrue(item.formattedSize.contains("GB") || item.formattedSize.contains("Go"))
    }

    func testCleanableItemCodable() throws {
        let item = CleanableItem(
            path: "/tmp/test",
            sizeBytes: 12345,
            safetyLevel: .caution,
            lastAccessed: Date(),
            description: "Test item"
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(CleanableItem.self, from: data)
        XCTAssertEqual(decoded.path, "/tmp/test")
        XCTAssertEqual(decoded.sizeBytes, 12345)
        XCTAssertEqual(decoded.safetyLevel, .caution)
        XCTAssertEqual(decoded.description, "Test item")
    }

    // MARK: - ScanResult

    func testScanResultEffectiveReclaimableBytes() {
        let result1 = ScanResult(
            categoryName: "Test",
            categoryIcon: "test",
            items: [],
            totalBytes: 1000,
            reclaimableBytes: 500,
            safetyLevel: .safe
        )
        XCTAssertEqual(result1.effectiveReclaimableBytes, 500)

        let result2 = ScanResult(
            categoryName: "Test",
            categoryIcon: "test",
            items: [],
            totalBytes: 1000,
            reclaimableBytes: nil,
            safetyLevel: .safe
        )
        XCTAssertEqual(result2.effectiveReclaimableBytes, 1000)
    }

    func testScanResultCodable() throws {
        let result = ScanResult(
            categoryName: "Docker",
            categoryIcon: "cube",
            items: [],
            totalBytes: 5000,
            reclaimableBytes: 2000,
            error: ScanError("test error"),
            safetyLevel: .safe
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(ScanResult.self, from: data)
        XCTAssertEqual(decoded.categoryName, "Docker")
        XCTAssertEqual(decoded.totalBytes, 5000)
        XCTAssertEqual(decoded.reclaimableBytes, 2000)
        XCTAssertEqual(decoded.error?.message, "test error")
    }

    // MARK: - StorageBreakdown

    func testStorageBreakdownAggregation() {
        let categories = [
            ScanResult(categoryName: "A", categoryIcon: "a", items: [], totalBytes: 1000, safetyLevel: .safe),
            ScanResult(categoryName: "B", categoryIcon: "b", items: [], totalBytes: 2000, safetyLevel: .safe),
            ScanResult(categoryName: "C", categoryIcon: "c", items: [], totalBytes: 0, safetyLevel: .safe),
        ]
        let breakdown = StorageBreakdown(categories: categories)

        XCTAssertEqual(breakdown.totalScannedBytes, 3000)
        XCTAssertEqual(breakdown.totalReclaimableBytes, 3000) // nil reclaimable = total
        XCTAssertEqual(breakdown.nonEmptyCategories.count, 2)
        XCTAssertEqual(breakdown.nonEmptyCategories.first?.categoryName, "B") // sorted by size desc
    }

    func testStorageBreakdownWithReclaimable() {
        let categories = [
            ScanResult(categoryName: "Docker", categoryIcon: "d", items: [], totalBytes: 10000, reclaimableBytes: 2000, safetyLevel: .safe),
            ScanResult(categoryName: "Xcode", categoryIcon: "x", items: [], totalBytes: 5000, safetyLevel: .safe),
        ]
        let breakdown = StorageBreakdown(categories: categories)

        XCTAssertEqual(breakdown.totalScannedBytes, 15000)
        XCTAssertEqual(breakdown.totalReclaimableBytes, 7000) // 2000 + 5000
    }

    func testStorageBreakdownVolumeInfo() {
        let info = StorageBreakdown.volumeInfo()
        // On any real machine, total should be > 0
        XCTAssertGreaterThan(info.total, 0)
        XCTAssertGreaterThanOrEqual(info.free, 0)
    }

    // MARK: - CleanupReport

    func testCleanupReport() {
        let report = CleanupReport(
            categoryName: "Test",
            itemsCleaned: 3,
            bytesFreed: 1_000_000_000,
            errors: [CleanupError(path: "/tmp/fail", message: "Permission denied")]
        )
        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(report.errors.count, 1)
        XCTAssertFalse(report.formattedBytesFreed.isEmpty)

        let clean = CleanupReport(categoryName: "Clean", itemsCleaned: 1, bytesFreed: 100)
        XCTAssertFalse(clean.hasErrors)
    }
}
