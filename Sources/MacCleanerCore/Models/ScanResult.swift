import Foundation

/// Result of scanning a single category.
public struct ScanResult: Codable, Sendable {
    public let categoryName: String
    public let categoryIcon: String
    public let items: [CleanableItem]
    public let totalBytes: Int64
    /// For command-based categories (Docker, Homebrew), the reclaimable amount
    /// may differ from total. Nil means total == reclaimable (file-based categories).
    public let reclaimableBytes: Int64?
    public let error: ScanError?
    public let safetyLevel: SafetyLevel

    public init(
        categoryName: String,
        categoryIcon: String,
        items: [CleanableItem],
        totalBytes: Int64,
        reclaimableBytes: Int64? = nil,
        error: ScanError? = nil,
        safetyLevel: SafetyLevel
    ) {
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.items = items
        self.totalBytes = totalBytes
        self.reclaimableBytes = reclaimableBytes
        self.error = error
        self.safetyLevel = safetyLevel
    }

    /// Effective reclaimable bytes. Falls back to totalBytes if not specified.
    public var effectiveReclaimableBytes: Int64 {
        reclaimableBytes ?? totalBytes
    }
}

/// A scan error that doesn't prevent other categories from scanning.
public struct ScanError: Codable, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }
}
