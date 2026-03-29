import Foundation

/// Xcode toolchains, SDKs, and command line tools in /Library/Developer.
/// This is separate from user-level ~/Library/Developer (DerivedData).
/// Shows per-subdirectory breakdown. Often 20-30 GB with multiple Xcode versions.
public final class XcodeToolchainsCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Xcode SDKs & Tools"
    public let icon = "wrench.and.screwdriver.fill"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let basePath = "/Library/Developer"
        guard FileManager.default.fileExists(atPath: basePath) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [],
                totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: basePath) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [],
                totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        for entry in entries {
            if Task.isCancelled { break }

            let fullPath = (basePath as NSString).appendingPathComponent(entry)
            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 10_000_000 {
                items.append(CleanableItem(
                    path: fullPath,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: "Xcode \(entry). Remove old versions via `sudo rm -rf`."
                ))
                totalBytes += size
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
