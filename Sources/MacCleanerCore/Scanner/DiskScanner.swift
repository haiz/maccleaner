import Foundation

/// Scans all categories in parallel and streams results progressively.
public final class DiskScanner: Sendable {

    /// All registered categories to scan.
    public let categories: [any ScannableCategory]

    public init(categories: [any ScannableCategory]? = nil) {
        self.categories = categories ?? Self.defaultCategories()
    }

    /// Default category registry — hardcoded, explicit.
    public static func defaultCategories() -> [any ScannableCategory] {
        [
            XcodeCategory(),
            XcodeSimulatorsCategory(),
            XcodeArchivesCategory(),
            DockerCategory(),
            NodeCategory(),
            HomebrewCategory(),
            AppCacheCategory(),
            UserLogsCategory(),
            SystemLogsCategory(),
            TimeMachineCategory(),
            IOSBackupCategory(),
            PackageCacheCategory(),
            // Space awareness categories
            ApplicationsCategory(),
            AppSupportCategory(),
            DevProjectsCategory(),
            DownloadsCategory(),
            UserFilesCategory(),
            // Deep scan categories
            HiddenDotfilesCategory(),
            XcodeToolchainsCategory(),
            AndroidSDKCategory(),
            LargeAppDataCategory(),
            // Orphaned app data (apps uninstalled but data remains)
            OrphanedAppDataCategory(),
            // System categories (non-user, non-cleanable)
            MacOSSystemCategory(),
            SystemStateCategory(),
            UncategorizedLibraryCategory(),
            // System health
            SystemHealthCategory(),
            SystemBinariesCategory(),
        ]
    }

    /// Scan all categories in parallel, streaming results as each completes.
    /// The returned AsyncStream emits one ScanResult per category.
    public func scanProgressively() -> AsyncStream<ScanResult> {
        let categories = self.categories

        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: ScanResult.self) { group in
                    for category in categories {
                        group.addTask {
                            await category.scan()
                        }
                    }

                    for await result in group {
                        if Task.isCancelled { break }
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Scan all categories and return a complete StorageBreakdown.
    /// Waits for all categories to complete.
    public func scanAll() async -> StorageBreakdown {
        var results: [ScanResult] = []

        for await result in scanProgressively() {
            results.append(result)
        }

        let volumeInfo = StorageBreakdown.volumeInfo()

        return StorageBreakdown(
            categories: results,
            scannedAt: Date(),
            totalDiskBytes: volumeInfo.total,
            freeDiskBytes: volumeInfo.free
        )
    }

    /// Re-scan a single category by name and return the updated result.
    public func rescanCategory(named name: String) async -> ScanResult? {
        guard let category = categories.first(where: { $0.name == name }) else {
            return nil
        }
        return await category.scan()
    }
}
