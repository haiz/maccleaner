import Foundation

/// Aggregated scan results across all categories.
public struct StorageBreakdown: Codable, Sendable {
    public let categories: [ScanResult]
    public let scannedAt: Date
    public let totalDiskBytes: Int64
    public let freeDiskBytes: Int64

    public init(
        categories: [ScanResult],
        scannedAt: Date = Date(),
        totalDiskBytes: Int64 = 0,
        freeDiskBytes: Int64 = 0
    ) {
        self.categories = categories
        self.scannedAt = scannedAt
        self.totalDiskBytes = totalDiskBytes
        self.freeDiskBytes = freeDiskBytes
    }

    /// Sum of all category sizes.
    public var totalScannedBytes: Int64 {
        categories.reduce(0) { $0 + $1.totalBytes }
    }

    /// Sum of all reclaimable bytes across categories.
    public var totalReclaimableBytes: Int64 {
        categories.reduce(0) { $0 + $1.effectiveReclaimableBytes }
    }

    /// Categories sorted by size descending, excluding zero-size results.
    public var nonEmptyCategories: [ScanResult] {
        categories
            .filter { $0.totalBytes > 0 }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    /// Fetches current disk volume info.
    public static func volumeInfo() -> (total: Int64, free: Int64) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        ) else {
            return (0, 0)
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        return (total, free)
    }
}
