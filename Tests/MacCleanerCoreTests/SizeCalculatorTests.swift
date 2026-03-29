import XCTest
@testable import MacCleanerCore

final class SizeCalculatorTests: XCTestCase {

    func testCalculateSizeOfNonExistentPath() async {
        let result = await SizeCalculator.calculateSize(at: "/nonexistent/path/that/doesnt/exist")
        if case .success(let size) = result {
            XCTAssertEqual(size, 0)
        } else {
            XCTFail("Expected success with 0 for non-existent path")
        }
    }

    func testCalculateSizeOfEmptyDirectory() async throws {
        let tmpDir = NSTemporaryDirectory() + "maccleaner-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let result = await SizeCalculator.calculateSize(at: tmpDir)
        if case .success(let size) = result {
            XCTAssertEqual(size, 0)
        } else {
            XCTFail("Expected success for empty directory")
        }
    }

    func testCalculateSizeOfDirectoryWithFiles() async throws {
        let tmpDir = NSTemporaryDirectory() + "maccleaner-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        // Create a file with some content
        let filePath = tmpDir + "/testfile.txt"
        let content = String(repeating: "x", count: 10000)
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)

        let result = await SizeCalculator.calculateSize(at: tmpDir)
        if case .success(let size) = result {
            XCTAssertGreaterThan(size, 0)
        } else {
            XCTFail("Expected success with positive size")
        }
    }

    func testCalculateTotalSizeMultiplePaths() async throws {
        let tmpDir1 = NSTemporaryDirectory() + "maccleaner-test1-\(UUID().uuidString)"
        let tmpDir2 = NSTemporaryDirectory() + "maccleaner-test2-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: tmpDir2, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tmpDir1)
            try? FileManager.default.removeItem(atPath: tmpDir2)
        }

        try "hello".write(toFile: tmpDir1 + "/a.txt", atomically: true, encoding: .utf8)
        try "world".write(toFile: tmpDir2 + "/b.txt", atomically: true, encoding: .utf8)

        let result = await SizeCalculator.calculateTotalSize(paths: [tmpDir1, tmpDir2, "/nonexistent"])
        if case .success(let size) = result {
            XCTAssertGreaterThan(size, 0)
        } else {
            XCTFail("Expected success")
        }
    }

    func testLastAccessDate() {
        // Home directory should have an access date
        let date = SizeCalculator.lastAccessDate(at: NSHomeDirectory())
        XCTAssertNotNil(date)

        // Non-existent path should return nil
        let noDate = SizeCalculator.lastAccessDate(at: "/nonexistent")
        XCTAssertNil(noDate)
    }
}
