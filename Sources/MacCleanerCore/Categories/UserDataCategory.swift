import Foundation

/// Downloads — scan-only. These are user files, NOT auto-generated.
/// Never include in batch cleanup. User must review in Finder manually.
public final class DownloadsCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Downloads"
    public let icon = "arrow.down.circle.fill"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let path = ("~/Downloads" as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [],
                totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        if let entries = try? FileManager.default.contentsOfDirectory(atPath: path) {
            for entry in entries {
                if Task.isCancelled { break }
                if entry.hasPrefix(".") { continue }
                let fullPath = (path as NSString).appendingPathComponent(entry)
                let result = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = result, size > 1_000_000 {
                    items.append(CleanableItem(
                        path: fullPath, sizeBytes: size, safetyLevel: .caution,
                        lastAccessed: SizeCalculator.lastAccessDate(at: fullPath),
                        description: "User file. Review in Finder."
                    ))
                    totalBytes += size
                }
            }
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }

        return ScanResult(
            categoryName: name, categoryIcon: icon, items: items,
            totalBytes: totalBytes, safetyLevel: safetyLevel
        )
    }
}

/// Combined user data: Documents, Desktop, Pictures, Movies, Music.
/// Scan-only: shows total size for awareness.
public final class UserFilesCategory: ScannableCategory, @unchecked Sendable {
    public let name = "User Files"
    public let icon = "person.crop.rectangle.fill"
    public let safetyLevel: SafetyLevel = .caution

    private let paths = [
        "~/Documents",
        "~/Desktop",
        "~/Pictures",
        "~/Movies",
        "~/Music",
    ]

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for path in paths {
            if Task.isCancelled { break }
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }

            let result = await SizeCalculator.calculateSize(at: expanded)
            if case .success(let size) = result, size > 0 {
                items.append(CleanableItem(
                    path: expanded,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: URL(fileURLWithPath: expanded).lastPathComponent
                ))
                totalBytes += size
            }
        }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }
}

/// ~/Library/Application Support — app data, databases, caches that apps need.
/// Scan-only for awareness. Individual subdirs could be cleanable but risky.
public final class AppSupportCategory: ScannableCategory, @unchecked Sendable {
    public let name = "App Support Data"
    public let icon = "externaldrive.fill"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let path = ("~/Library/Application Support" as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [], totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        // Scan top-level subdirs to show per-app breakdown
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return ScanResult(
                categoryName: name, categoryIcon: icon, items: [], totalBytes: 0, safetyLevel: safetyLevel
            )
        }

        for entry in entries {
            if Task.isCancelled { break }
            let fullPath = (path as NSString).appendingPathComponent(entry)
            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 50_000_000 { // Only show > 50MB
                items.append(CleanableItem(
                    path: fullPath,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: entry
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

/// Developer projects — ~/code and similar directories.
/// EXCLUDES node_modules (counted by NodeCategory) to avoid double-counting.
public final class DevProjectsCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Developer Projects"
    public let icon = "chevron.left.forwardslash.chevron.right"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        let candidates = ["~/code", "~/Projects", "~/Developer", "~/repos"]
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for path in candidates {
            if Task.isCancelled { break }
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }

            // Get total size
            let result = await SizeCalculator.calculateSize(at: expanded)
            guard case .success(var size) = result, size > 0 else { continue }

            // Subtract node_modules sizes (counted separately by NodeCategory)
            let nmSize = await nodeModulesSize(in: expanded)
            size -= nmSize

            if size > 0 {
                items.append(CleanableItem(
                    path: expanded,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: "\(URL(fileURLWithPath: expanded).lastPathComponent) (excluding node_modules)"
                ))
                totalBytes += size
            }
        }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }

    private func nodeModulesSize(in directory: String, depth: Int = 0) async -> Int64 {
        if depth > 4 { return 0 }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directory) else { return 0 }
        var total: Int64 = 0
        for entry in entries {
            if Task.isCancelled { break }
            if entry.hasPrefix(".") { continue }
            let fullPath = (directory as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
            if entry == "node_modules" {
                let result = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = result { total += size }
            } else {
                total += await nodeModulesSize(in: fullPath, depth: depth + 1)
            }
        }
        return total
    }
}
