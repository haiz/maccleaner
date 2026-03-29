import Foundation

/// Base class for categories that scan known fixed paths and clean via FileManager.trashItem.
/// Concrete categories provide paths, name, icon, safety level, and descriptions.
open class FileBasedCategory: CleanableCategory, @unchecked Sendable {
    public let name: String
    public let icon: String
    public let safetyLevel: SafetyLevel
    public let scanPaths: [String]
    private let itemDescription: String

    public init(
        name: String,
        icon: String,
        safetyLevel: SafetyLevel,
        scanPaths: [String],
        itemDescription: String = ""
    ) {
        self.name = name
        self.icon = icon
        self.safetyLevel = safetyLevel
        self.scanPaths = scanPaths
        self.itemDescription = itemDescription
    }

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0
        var scanError: ScanError?

        for path in scanPaths {
            if Task.isCancelled { break }

            let expandedPath = (path as NSString).expandingTildeInPath
            let fm = FileManager.default

            guard fm.fileExists(atPath: expandedPath) else { continue }

            let result = await SizeCalculator.calculateSize(at: expandedPath)
            switch result {
            case .success(let size) where size > 0:
                let item = CleanableItem(
                    path: expandedPath,
                    sizeBytes: size,
                    safetyLevel: safetyLevel,
                    lastAccessed: SizeCalculator.lastAccessDate(at: expandedPath),
                    description: itemDescription
                )
                items.append(item)
                totalBytes += size
            case .failure(let error):
                scanError = ScanError(error.localizedDescription)
            default:
                break
            }
        }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
            error: scanError,
            safetyLevel: safetyLevel
        )
    }

    public func clean(items: [CleanableItem]) async -> CleanupReport {
        var cleaned = 0
        var bytesFreed: Int64 = 0
        var errors: [CleanupError] = []
        let fm = FileManager.default

        for item in items {
            if Task.isCancelled { break }

            let url = URL(fileURLWithPath: item.path)

            // First try trashing the entire directory
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                cleaned += 1
                bytesFreed += item.sizeBytes
            } catch {
                // If trashing the whole directory fails (e.g., ~/Library/Caches is in use),
                // fall back to trashing individual subdirectories inside it.
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let subResult = await cleanSubdirectories(at: item.path)
                    cleaned += subResult.cleaned
                    bytesFreed += subResult.freed
                    errors.append(contentsOf: subResult.errors)
                } else {
                    errors.append(CleanupError(
                        path: item.path,
                        message: error.localizedDescription
                    ))
                }
            }
        }

        return CleanupReport(
            categoryName: name,
            itemsCleaned: cleaned,
            bytesFreed: bytesFreed,
            errors: errors
        )
    }

    /// Trash individual subdirectories when the parent can't be trashed.
    private func cleanSubdirectories(at path: String) async -> (cleaned: Int, freed: Int64, errors: [CleanupError]) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else {
            return (0, 0, [CleanupError(path: path, message: "Cannot list directory contents")])
        }

        var cleaned = 0
        var freed: Int64 = 0
        var errors: [CleanupError] = []

        for entry in entries {
            if Task.isCancelled { break }

            // Skip macOS system caches (always in use by system daemons)
            if entry.hasPrefix("com.apple.") || entry == "CloudKit" { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            let url = URL(fileURLWithPath: fullPath)

            // Get size before deleting
            let sizeResult = await SizeCalculator.calculateSize(at: fullPath)
            let size: Int64
            if case .success(let s) = sizeResult { size = s } else { size = 0 }

            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                cleaned += 1
                freed += size
            } catch {
                // Skip items in use (this is expected for active app caches)
                errors.append(CleanupError(
                    path: fullPath,
                    message: "In use by running app"
                ))
            }
        }

        return (cleaned, freed, errors)
    }
}
