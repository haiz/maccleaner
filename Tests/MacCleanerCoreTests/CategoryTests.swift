import XCTest
@testable import MacCleanerCore

final class CategoryTests: XCTestCase {

    // MARK: - FileBasedCategory

    func testFileBasedCategoryWithExistingPath() async {
        // ~/Library/Caches almost certainly exists
        let category = AppCacheCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "App Caches")
        XCTAssertNil(result.error)
        // On a real machine, caches should have some size
        XCTAssertGreaterThan(result.totalBytes, 0)
        XCTAssertFalse(result.items.isEmpty)
    }

    func testFileBasedCategoryWithNonExistentPath() async {
        let category = FileBasedCategory(
            name: "Fake",
            icon: "test",
            safetyLevel: .safe,
            scanPaths: ["/nonexistent/path/that/doesnt/exist"]
        )
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "Fake")
        XCTAssertEqual(result.totalBytes, 0)
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNil(result.error)
    }

    func testFileBasedCategoryCleanEmptyItems() async {
        let category = FileBasedCategory(
            name: "Test",
            icon: "test",
            safetyLevel: .safe,
            scanPaths: []
        )
        let report = await category.clean(items: [])

        XCTAssertEqual(report.itemsCleaned, 0)
        XCTAssertEqual(report.bytesFreed, 0)
        XCTAssertFalse(report.hasErrors)
    }

    // MARK: - XcodeCategory

    func testXcodeCategoryScan() async {
        let category = XcodeCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "Xcode DerivedData")
        XCTAssertEqual(result.safetyLevel, .safe)
        // Size could be 0 if no Xcode projects built
        XCTAssertNil(result.error)
    }

    // MARK: - DockerCategory

    func testDockerCategoryScanWhenNotInstalled() async {
        // If Docker data directory doesn't exist, should return error
        let category = DockerCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "Docker")
        // Either has data or has an error — both are valid
        if result.totalBytes == 0 {
            // Docker may not be installed — that's fine
            XCTAssertTrue(result.items.isEmpty || result.error != nil)
        }
    }

    func testDockerCategoryIsIrreversible() {
        let category = DockerCategory()
        XCTAssertTrue(category.isIrreversible)
    }

    // MARK: - HomebrewCategory

    func testHomebrewCategoryScan() async {
        let category = HomebrewCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "Homebrew")
        // Homebrew may or may not be installed
    }

    func testHomebrewCategoryIsIrreversible() {
        let category = HomebrewCategory()
        XCTAssertTrue(category.isIrreversible)
    }

    // MARK: - NodeCategory

    func testNodeCategoryWithNoRoots() async {
        let category = NodeCategory(projectRoots: ["/nonexistent/root"], maxDepth: 2)
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "node_modules")
        XCTAssertEqual(result.totalBytes, 0)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testNodeCategorySortsBySize() async {
        // If there are node_modules, they should be sorted by size descending
        let category = NodeCategory()
        let result = await category.scan()

        if result.items.count > 1 {
            for i in 0..<(result.items.count - 1) {
                XCTAssertGreaterThanOrEqual(result.items[i].sizeBytes, result.items[i + 1].sizeBytes)
            }
        }
    }

    // MARK: - Scan-only categories

    func testSystemLogsCategoryIsScanOnly() async {
        let category = SystemLogsCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "System Logs")
        // Should work even without root — size may be 0 due to permissions
    }

    func testTimeMachineCategoryIsScanOnly() async {
        let category = TimeMachineCategory()
        let result = await category.scan()

        XCTAssertEqual(result.categoryName, "Time Machine")
        // May have 0 bytes if no local snapshots
    }

    // MARK: - Protocol conformance

    func testAllDefaultCategoriesAreRegistered() {
        let categories = DiskScanner.defaultCategories()
        XCTAssertEqual(categories.count, 27)

        let names = categories.map { $0.name }
        XCTAssertTrue(names.contains("Xcode DerivedData"))
        XCTAssertTrue(names.contains("Docker"))
        XCTAssertTrue(names.contains("node_modules"))
        XCTAssertTrue(names.contains("Homebrew"))
        XCTAssertTrue(names.contains("App Caches"))
    }
}
