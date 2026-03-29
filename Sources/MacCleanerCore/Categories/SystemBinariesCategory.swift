import Foundation

/// System binaries and frameworks: /usr, /opt, /Library/Frameworks, /Library/Developer.
/// Scan-only: these are OS and dev tool installations, not user-cleanable.
/// Shows breakdown so users understand where space goes.
public final class SystemBinariesCategory: ScannableCategory, @unchecked Sendable {
    public let name = "System & Tools"
    public let icon = "gearshape.2.fill"
    public let safetyLevel: SafetyLevel = .caution

    private let paths: [(path: String, description: String)] = [
        ("/usr/local", "Homebrew (Intel) + local binaries"),
        ("/opt/homebrew", "Homebrew (Apple Silicon)"),
        ("/Library/Frameworks", "System frameworks (Python, Mono, etc.)"),
        ("/Library/Developer", "Xcode command line tools + SDKs"),
        ("/Library/PostgreSQL", "PostgreSQL server"),
        ("/Library/Java", "Java JDK installations"),
        ("/Library/Updates", "macOS pending updates"),
    ]

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for entry in paths {
            if Task.isCancelled { break }
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }

            let result = await SizeCalculator.calculateSize(at: entry.path)
            if case .success(let size) = result, size > 10_000_000 { // > 10MB
                items.append(CleanableItem(
                    path: entry.path,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: entry.description
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
