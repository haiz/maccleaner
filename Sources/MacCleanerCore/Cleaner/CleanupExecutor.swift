import Foundation

/// Thin orchestrator: delegates cleanup to the category, then triggers re-scan.
public final class CleanupExecutor: Sendable {

    private let scanner: DiskScanner

    public init(scanner: DiskScanner) {
        self.scanner = scanner
    }

    /// Clean items for a specific category, then re-scan that category.
    /// Returns the cleanup report and the updated scan result.
    public func cleanAndRescan(
        category: any CleanableCategory,
        items: [CleanableItem]
    ) async -> (report: CleanupReport, updatedScan: ScanResult?) {
        let report = await category.clean(items: items)
        let updatedScan = await scanner.rescanCategory(named: category.name)
        return (report, updatedScan)
    }

    /// Find a CleanableCategory by name from the scanner's registry.
    public func findCleanableCategory(named name: String) -> (any CleanableCategory)? {
        scanner.categories.first { $0.name == name } as? (any CleanableCategory)
    }
}
