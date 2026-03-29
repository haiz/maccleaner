import Foundation

/// A single item that can potentially be cleaned (file or directory).
public struct CleanableItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let sizeBytes: Int64
    public let safetyLevel: SafetyLevel
    public let lastAccessed: Date?
    public let description: String

    public init(
        path: String,
        sizeBytes: Int64,
        safetyLevel: SafetyLevel,
        lastAccessed: Date? = nil,
        description: String = ""
    ) {
        self.id = UUID()
        self.path = path
        self.sizeBytes = sizeBytes
        self.safetyLevel = safetyLevel
        self.lastAccessed = lastAccessed
        self.description = description
    }
}

extension CleanableItem {
    /// Human-readable size string (e.g., "4.2 GB").
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
