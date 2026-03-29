import Foundation

/// Result of a cleanup operation on one or more items.
public struct CleanupReport: Codable, Sendable {
    public let categoryName: String
    public let itemsCleaned: Int
    public let bytesFreed: Int64
    public let errors: [CleanupError]

    public init(
        categoryName: String,
        itemsCleaned: Int,
        bytesFreed: Int64,
        errors: [CleanupError] = []
    ) {
        self.categoryName = categoryName
        self.itemsCleaned = itemsCleaned
        self.bytesFreed = bytesFreed
        self.errors = errors
    }

    public var hasErrors: Bool { !errors.isEmpty }

    /// Human-readable bytes freed string.
    public var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }
}

public struct CleanupError: Codable, Sendable {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}
