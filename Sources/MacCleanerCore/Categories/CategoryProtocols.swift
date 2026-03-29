import Foundation

/// A category that can scan a portion of the disk and report its size.
public protocol ScannableCategory: Sendable {
    var name: String { get }
    var icon: String { get }
    var safetyLevel: SafetyLevel { get }

    /// Scan this category's paths and return the result.
    /// Must handle errors gracefully (return ScanResult with error, never throw).
    func scan() async -> ScanResult
}

/// A category that can also clean up items it discovered during scanning.
/// Each category owns its cleanup logic internally (Trash vs Command).
public protocol CleanableCategory: ScannableCategory {
    /// Clean the specified items. The category decides HOW (Trash or Command).
    /// Returns a report of what was cleaned and any errors encountered.
    func clean(items: [CleanableItem]) async -> CleanupReport

    /// Whether this category's cleanup is irreversible (command-based like Docker, Homebrew).
    /// File-based categories that use Trash are reversible.
    var isIrreversible: Bool { get }
}

extension CleanableCategory {
    /// Default: file-based categories are reversible (items go to Trash).
    public var isIrreversible: Bool { false }
}
