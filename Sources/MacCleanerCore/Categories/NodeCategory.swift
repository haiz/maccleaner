import Foundation

/// node_modules — discovers scattered node_modules directories via filesystem walk
/// with configurable project root directories.
public final class NodeCategory: CleanableCategory, @unchecked Sendable {
    public let name = "node_modules"
    public let icon = "shippingbox"
    public let safetyLevel: SafetyLevel = .safe

    /// Configurable project root directories to scan.
    /// Defaults to common developer locations.
    public var projectRoots: [String]

    /// Maximum directory depth to search for node_modules.
    public let maxDepth: Int

    public init(
        projectRoots: [String] = [
            "~/code",
            "~/Projects",
            "~/Developer",
            "~/Desktop",
        ],
        maxDepth: Int = 4
    ) {
        self.projectRoots = projectRoots
        self.maxDepth = maxDepth
    }

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for root in projectRoots {
            if Task.isCancelled { break }

            let expandedRoot = (root as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedRoot) else { continue }

            let discovered = await discoverNodeModules(in: expandedRoot, currentDepth: 0)
            for (path, size) in discovered {
                if Task.isCancelled { break }

                let item = CleanableItem(
                    path: path,
                    sizeBytes: size,
                    safetyLevel: safetyLevel,
                    lastAccessed: SizeCalculator.lastAccessDate(at: path),
                    description: "node_modules — restore with npm/pnpm install"
                )
                items.append(item)
                totalBytes += size
            }
        }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items.sorted { $0.sizeBytes > $1.sizeBytes },
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }

    public func clean(items: [CleanableItem]) async -> CleanupReport {
        var cleaned = 0
        var bytesFreed: Int64 = 0
        var errors: [CleanupError] = []

        for item in items {
            if Task.isCancelled { break }

            let url = URL(fileURLWithPath: item.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                cleaned += 1
                bytesFreed += item.sizeBytes
            } catch {
                errors.append(CleanupError(
                    path: item.path,
                    message: error.localizedDescription
                ))
            }
        }

        return CleanupReport(
            categoryName: name,
            itemsCleaned: cleaned,
            bytesFreed: bytesFreed,
            errors: errors
        )
    }

    // MARK: - Private

    /// Recursively discover node_modules directories, stopping descent when found.
    private func discoverNodeModules(
        in directory: String,
        currentDepth: Int
    ) async -> [(path: String, size: Int64)] {
        if currentDepth > maxDepth || Task.isCancelled { return [] }

        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        var results: [(String, Int64)] = []

        for entry in entries {
            if Task.isCancelled { break }

            let fullPath = (directory as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Skip hidden directories
            if entry.hasPrefix(".") { continue }

            if entry == "node_modules" {
                // Found one — measure size, do NOT recurse into it
                let sizeResult = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = sizeResult, size > 0 {
                    results.append((fullPath, size))
                }
            } else {
                // Recurse into subdirectory
                let subResults = await discoverNodeModules(in: fullPath, currentDepth: currentDepth + 1)
                results.append(contentsOf: subResults)
            }
        }

        return results
    }
}
