import Foundation

/// Installed applications — /Applications and ~/Applications.
/// Scan-only: shows size but doesn't offer cleanup (users manage apps themselves).
public final class ApplicationsCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Applications"
    public let icon = "app.badge"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        let appDirs = ["/Applications", ("~/Applications" as NSString).expandingTildeInPath]

        for dir in appDirs {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }

            for entry in entries {
                if Task.isCancelled { break }
                let fullPath = (dir as NSString).appendingPathComponent(entry)

                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                let result = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = result, size > 10_000_000 { // Only show apps > 10MB
                    items.append(CleanableItem(
                        path: fullPath,
                        sizeBytes: size,
                        safetyLevel: .caution,
                        lastAccessed: SizeCalculator.lastAccessDate(at: fullPath),
                        description: entry
                    ))
                    totalBytes += size
                }
            }
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }
}
