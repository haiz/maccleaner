import Foundation

/// Large app data in ~/Library/Application Support and ~/Library/Containers.
/// Shows per-app breakdown for the biggest consumers.
/// Distinct from AppCacheCategory (~/Library/Caches) — this is persistent app data.
public final class LargeAppDataCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Large App Data"
    public let icon = "app.dashed"
    public let safetyLevel: SafetyLevel = .caution

    /// Paths already covered by other categories (to avoid double-counting).
    private let excludedPaths: Set<String> = [
        "com.docker.docker",  // Covered by DockerCategory
    ]

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        // Scan ~/Library/Containers (excluding Docker)
        let containersPath = ("~/Library/Containers" as NSString).expandingTildeInPath
        await scanDirectory(containersPath, into: &items, total: &totalBytes, minSize: 200_000_000)

        // Scan ~/Library/Group Containers
        let groupPath = ("~/Library/Group Containers" as NSString).expandingTildeInPath
        await scanDirectory(groupPath, into: &items, total: &totalBytes, minSize: 200_000_000)

        items.sort { $0.sizeBytes > $1.sizeBytes }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }

    private func scanDirectory(
        _ path: String,
        into items: inout [CleanableItem],
        total: inout Int64,
        minSize: Int64
    ) async {
        guard FileManager.default.fileExists(atPath: path) else { return }
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }

        for entry in entries {
            if Task.isCancelled { break }
            guard !excludedPaths.contains(entry) else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > minSize {
                // Try to get a friendly app name from the bundle ID
                let friendlyName = Self.friendlyName(for: entry)
                items.append(CleanableItem(
                    path: fullPath,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: "\(friendlyName) container data"
                ))
                total += size
            }
        }
    }

    /// Convert bundle ID to a friendlier name.
    private static func friendlyName(for bundleID: String) -> String {
        let mappings: [String: String] = [
            "com.tinyspeck.slackmacgap": "Slack",
            "com.microsoft.teams2": "Microsoft Teams",
            "com.apple.geod": "Apple Maps",
            "com.apple.mediaanalysisd": "Photos Analysis",
            "com.sequel-ace.sequel-ace": "Sequel Ace",
            "com.apple.wallpaper.agent": "Wallpaper",
        ]
        return mappings[bundleID] ?? bundleID
    }
}
