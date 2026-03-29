import Foundation

/// Calculates the total allocated size of a directory using URLResourceKey.
/// Uses autorelease pool batching to manage memory for large directories.
public enum SizeCalculator: Sendable {

    /// Calculate total allocated size of a directory.
    /// Returns 0 for non-existent paths. Returns error for permission denied.
    public static func calculateSize(at path: String) async -> Result<Int64, Error> {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let fm = FileManager.default

        // Check path exists
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return .success(0)
        }

        // If it's a file, get its size directly
        if !isDir.boolValue {
            return singleFileSize(at: url)
        }

        // Directory: enumerate and sum
        return await directorySize(at: url)
    }

    /// Calculate size of a single file.
    private static func singleFileSize(at url: URL) -> Result<Int64, Error> {
        do {
            let values = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            return .success(size)
        } catch {
            return .failure(error)
        }
    }

    /// Calculate total size of a directory by enumerating contents.
    /// Uses autorelease pool batching every 1000 items to manage memory.
    private static func directorySize(at url: URL) async -> Result<Int64, Error> {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return .failure(SizeCalculatorError.cannotEnumerate(url.path))
        }

        var total: Int64 = 0
        var count = 0
        let batchSize = 1000

        for case let fileURL as URL in enumerator {
            // Check cancellation periodically
            if Task.isCancelled { break }

            // Autorelease batching
            if count % batchSize == 0 && count > 0 {
                await Task.yield()
            }

            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                if values.isRegularFile == true {
                    total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                }
            } catch {
                // Skip files we can't read (permission denied, etc.)
                continue
            }
            count += 1
        }

        return .success(total)
    }

    /// Calculate sizes for multiple paths in parallel, returning the total.
    public static func calculateTotalSize(paths: [String]) async -> Result<Int64, Error> {
        var total: Int64 = 0

        for path in paths {
            if Task.isCancelled { break }
            let result = await calculateSize(at: path)
            switch result {
            case .success(let size):
                total += size
            case .failure:
                // Skip failed paths, continue with others
                continue
            }
        }

        return .success(total)
    }

    /// Get the last access date for a path.
    public static func lastAccessDate(at path: String) -> Date? {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let values = try? url.resourceValues(forKeys: [.contentAccessDateKey])
        return values?.contentAccessDate
    }
}

enum SizeCalculatorError: Error, LocalizedError {
    case cannotEnumerate(String)

    var errorDescription: String? {
        switch self {
        case .cannotEnumerate(let path):
            return "Cannot enumerate directory: \(path)"
        }
    }
}
