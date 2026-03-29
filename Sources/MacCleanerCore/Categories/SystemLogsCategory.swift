import Foundation

/// System logs — /var/log. Scan-only in GUI (requires sudo for cleanup).
public final class SystemLogsCategory: ScannableCategory, @unchecked Sendable {
    public let name = "System Logs"
    public let icon = "doc.text.magnifyingglass"
    public let safetyLevel: SafetyLevel = .safe

    public init() {}

    public func scan() async -> ScanResult {
        let path = "/var/log"

        guard FileManager.default.fileExists(atPath: path) else {
            return ScanResult(
                categoryName: name,
                categoryIcon: icon,
                items: [],
                totalBytes: 0,
                safetyLevel: safetyLevel
            )
        }

        let result = await SizeCalculator.calculateSize(at: path)
        let totalBytes: Int64
        switch result {
        case .success(let size): totalBytes = size
        case .failure: totalBytes = 0
        }

        let item = CleanableItem(
            path: path,
            sizeBytes: totalBytes,
            safetyLevel: safetyLevel,
            description: "System logs. Requires sudo to clean (use CLI: sudo maccleaner clean --category system-logs)."
        )

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: totalBytes > 0 ? [item] : [],
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }
}
