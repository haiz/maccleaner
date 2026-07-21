import Foundation

/// An immediate child of a directory, with its own total size.
/// Used by the GUI to lazily expand a folder and reveal its sub-items.
public struct DirectoryEntry: Identifiable, Sendable, Hashable {
    public let path: String
    public let name: String
    public let sizeBytes: Int64
    public let isDirectory: Bool

    public var id: String { path }

    public init(path: String, name: String, sizeBytes: Int64, isDirectory: Bool) {
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }
}

extension DirectoryEntry {
    /// Human-readable size string (e.g., "4.2 GB").
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
