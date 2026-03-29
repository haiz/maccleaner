import Foundation

/// macOS system files: /System/Library, /System/Applications, /System/iOSSupport.
/// These are firmlinked from the System volume to the Data volume.
/// View-only: cannot be deleted.
public final class MacOSSystemCategory: ScannableCategory, @unchecked Sendable {
    public let name = "macOS System"
    public let icon = "apple.logo"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let paths: [(path: String, desc: String)] = [
            ("/System/Library", """
                The core of macOS itself. Contains all the frameworks (code libraries) that every app on your Mac depends on, \
                plus system assets like fonts, wallpapers, sounds, and language data. \
                This is the largest system folder because it includes everything from Safari's web engine to Siri's speech models.\n\n\
                Cannot be deleted. Protected by System Integrity Protection (SIP).
                """),
            ("/System/Applications", """
                Built-in macOS apps that come pre-installed: Finder, Safari, Mail, Calendar, Photos, \
                Music, App Store, Terminal, and more. These apps cannot be removed because other parts \
                of macOS depend on them.\n\n\
                Cannot be deleted. Even if you never use some of these apps, they must stay.
                """),
            ("/System/iOSSupport", """
                Compatibility layer that allows iPhone and iPad apps to run on your Mac (Apple Silicon). \
                Contains iOS frameworks translated for macOS. Required for running any iOS app from the App Store on your Mac.\n\n\
                Cannot be deleted. Required by macOS for iOS app compatibility.
                """),
        ]

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for entry in paths {
            if Task.isCancelled { break }
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            let result = await SizeCalculator.calculateSize(at: entry.path)
            if case .success(let size) = result, size > 0 {
                items.append(CleanableItem(
                    path: entry.path, sizeBytes: size, safetyLevel: .caution,
                    description: entry.desc
                ))
                totalBytes += size
            }
        }

        return ScanResult(
            categoryName: name, categoryIcon: icon, items: items,
            totalBytes: totalBytes, safetyLevel: safetyLevel
        )
    }
}

/// System state: /private/var (databases, temp caches, logs).
/// View-only. Managed by macOS automatically.
public final class SystemStateCategory: ScannableCategory, @unchecked Sendable {
    public let name = "System State"
    public let icon = "server.rack"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let paths: [(path: String, desc: String)] = [
            ("/private/var/folders", """
                Temporary working space for each user and each app. macOS creates folders here when apps need \
                a place to store short-lived data (thumbnails, previews, compiled scripts). \
                Automatically cleaned by macOS on restart, but accumulates during long uptime.\n\n\
                Restart your Mac to let macOS clean this automatically.
                """),
            ("/private/var/db", """
                System databases that macOS uses internally. Includes the Spotlight search index \
                (which lets you search files instantly), APFS filesystem metadata, diagnostics data, \
                and configuration databases.\n\n\
                Cannot be deleted. Spotlight index rebuilds automatically if damaged, but this takes hours.
                """),
            ("/private/var/tmp", """
                System temporary files. Apps and macOS write scratch data here during operations. \
                Normally small. macOS cleans it periodically.\n\n\
                Cleaned automatically on restart.
                """),
            ("/private/var/log", """
                System log files. Records of what macOS and background services are doing. \
                Used for troubleshooting when something goes wrong. Rotated automatically \
                (old logs are compressed and eventually deleted).\n\n\
                Generally small. Cleaned automatically by macOS log rotation.
                """),
        ]

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for entry in paths {
            if Task.isCancelled { break }
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            let result = await SizeCalculator.calculateSize(at: entry.path)
            if case .success(let size) = result, size > 10_000_000 {
                items.append(CleanableItem(
                    path: entry.path, sizeBytes: size, safetyLevel: .caution,
                    description: entry.desc
                ))
                totalBytes += size
            }
        }

        return ScanResult(
            categoryName: name, categoryIcon: icon, items: items,
            totalBytes: totalBytes, safetyLevel: safetyLevel
        )
    }
}

/// Uncategorized files in ~/Library that don't belong to any other category.
/// Catches small scattered files that individually are tiny but add up.
public final class UncategorizedLibraryCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Other ~/Library"
    public let icon = "questionmark.folder"
    public let safetyLevel: SafetyLevel = .caution

    /// Directories already covered by other categories.
    private let coveredDirs: Set<String> = [
        "Application Support", "Containers", "Group Containers",
        "GroupContainersAlias", "Caches", "Logs", "Developer",
        "Android", "pnpm",
    ]

    public init() {}

    public func scan() async -> ScanResult {
        let libPath = ("~/Library" as NSString).expandingTildeInPath
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: libPath) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [],
                totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for entry in entries {
            if Task.isCancelled { break }
            if coveredDirs.contains(entry) { continue }

            let fullPath = (libPath as NSString).appendingPathComponent(entry)
            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 10_000_000 { // > 10MB
                items.append(CleanableItem(
                    path: fullPath, sizeBytes: size, safetyLevel: .caution,
                    description: entry
                ))
                totalBytes += size
            }
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }

        return ScanResult(
            categoryName: name, categoryIcon: icon, items: items,
            totalBytes: totalBytes, safetyLevel: safetyLevel
        )
    }
}
