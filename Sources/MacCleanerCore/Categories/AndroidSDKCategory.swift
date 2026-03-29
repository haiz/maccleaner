import Foundation

/// Android SDK — emulators, build tools, platform versions.
/// Often 8-15 GB. Old platform versions can be safely removed via Android Studio SDK Manager.
public final class AndroidSDKCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Android SDK"
    public let icon = "cpu.fill"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        // NOTE: ~/.android is covered by HiddenDotfilesCategory. Only scan ~/Library/Android/sdk here.
        let paths = [
            ("~/Library/Android/sdk" as NSString).expandingTildeInPath,
        ]

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for path in paths {
            if Task.isCancelled { break }
            guard FileManager.default.fileExists(atPath: path) else { continue }

            // Scan subdirectories for breakdown
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { continue }

            for entry in entries {
                if Task.isCancelled { break }
                let fullPath = (path as NSString).appendingPathComponent(entry)
                let result = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = result, size > 50_000_000 {
                    items.append(CleanableItem(
                        path: fullPath,
                        sizeBytes: size,
                        safetyLevel: .caution,
                        description: "Android \(entry). Manage via Android Studio SDK Manager."
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
