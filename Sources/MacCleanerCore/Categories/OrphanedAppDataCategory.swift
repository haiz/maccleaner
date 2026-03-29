import Foundation

/// Detects leftover data from apps that have been uninstalled.
/// Cross-references ~/Library/Containers, ~/Library/Application Support,
/// ~/Library/Caches, and ~/Library/Preferences against installed apps in /Applications.
/// Orphaned data is SAFE to delete because the app no longer exists.
public final class OrphanedAppDataCategory: CleanableCategory, @unchecked Sendable {
    public let name = "Uninstalled App Leftovers"
    public let icon = "trash.circle.fill"
    public let safetyLevel: SafetyLevel = .safe

    public init() {}

    public func scan() async -> ScanResult {
        // 1. Build set of installed app bundle IDs and names
        let installed = await getInstalledApps()

        // 2. Scan locations for orphaned data
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        // Check ~/Library/Containers (bundle ID based)
        await scanContainers(installed: installed, items: &items, total: &totalBytes)

        // Check ~/Library/Application Support (name based)
        await scanAppSupport(installed: installed, items: &items, total: &totalBytes)

        // Check ~/Library/Caches (bundle ID or name based)
        await scanCaches(installed: installed, items: &items, total: &totalBytes)

        // Check home directory dotfiles belonging to uninstalled apps
        await scanOrphanedDotfiles(installed: installed, items: &items, total: &totalBytes)

        items.sort { $0.sizeBytes > $1.sizeBytes }

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: items,
            totalBytes: totalBytes,
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

            // Try trashing the entire directory first
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                cleaned += 1
                bytesFreed += item.sizeBytes
            } catch {
                // macOS Container Manager protects some metadata files inside ~/Library/Containers.
                // Fall back to trashing individual contents (skip system metadata files).
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    if let entries = try? fm.contentsOfDirectory(atPath: item.path) {
                        var subCleaned = false
                        for entry in entries {
                            if Task.isCancelled { break }
                            // Skip Apple system metadata
                            if entry.hasPrefix(".com.apple.") { continue }
                            let subPath = (item.path as NSString).appendingPathComponent(entry)
                            let subURL = URL(fileURLWithPath: subPath)
                            let sizeResult = await SizeCalculator.calculateSize(at: subPath)
                            let subSize: Int64 = if case .success(let s) = sizeResult { s } else { 0 }
                            do {
                                try fm.trashItem(at: subURL, resultingItemURL: nil)
                                bytesFreed += subSize
                                subCleaned = true
                            } catch {
                                errors.append(CleanupError(path: subPath, message: "Protected by macOS"))
                            }
                        }
                        if subCleaned { cleaned += 1 }
                    }
                } else {
                    errors.append(CleanupError(path: item.path, message: error.localizedDescription))
                }
            }
        }

        return CleanupReport(categoryName: name, itemsCleaned: cleaned, bytesFreed: bytesFreed, errors: errors)
    }

    // MARK: - Private

    private struct InstalledApp {
        let bundleID: String
        let name: String
        let nameLowered: String
    }

    private func getInstalledApps() async -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default

        let appDirs = ["/Applications", "/System/Applications",
                       ("~/Applications" as NSString).expandingTildeInPath]

        for dir in appDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let plistPath = "\(dir)/\(entry)/Contents/Info.plist"
                if let data = fm.contents(atPath: plistPath),
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                   let bundleID = plist["CFBundleIdentifier"] as? String {
                    let name = entry.replacingOccurrences(of: ".app", with: "")
                    apps.append(InstalledApp(bundleID: bundleID, name: name, nameLowered: name.lowercased()))
                }
            }
        }

        return apps
    }

    private func isOrphaned(_ identifier: String, installed: [InstalledApp]) -> Bool {
        let lowered = identifier.lowercased()

        // Skip Apple system services (always present, no .app)
        if lowered.hasPrefix("com.apple.") { return false }

        // Check against installed bundle IDs
        for app in installed {
            if app.bundleID.lowercased() == lowered { return false }
            // Partial match: "com.tinyspeck.slackmacgap" matches app "Slack"
            if lowered.contains(app.nameLowered) { return false }
            if app.bundleID.lowercased().contains(lowered) { return false }
        }

        // Check against installed app names (for ~/Library/Application Support which uses names)
        for app in installed {
            if app.nameLowered == lowered { return false }
            // Fuzzy: "Google" matches "Google Chrome"
            if app.nameLowered.contains(lowered) || lowered.contains(app.nameLowered) { return false }
        }

        return true
    }

    private func scanContainers(installed: [InstalledApp], items: inout [CleanableItem], total: inout Int64) async {
        let path = ("~/Library/Containers" as NSString).expandingTildeInPath
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }

        for entry in entries {
            if Task.isCancelled { break }
            guard isOrphaned(entry, installed: installed) else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 1_000_000 { // > 1MB
                items.append(CleanableItem(
                    path: fullPath, sizeBytes: size, safetyLevel: .safe,
                    description: "Container data for uninstalled app '\(entry)'. Safe to delete."
                ))
                total += size
            }
        }
    }

    private func scanAppSupport(installed: [InstalledApp], items: inout [CleanableItem], total: inout Int64) async {
        let path = ("~/Library/Application Support" as NSString).expandingTildeInPath
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }

        // Known system dirs that are NOT app data
        let systemDirs: Set<String> = [
            "AddressBook", "CrashReporter", "com.apple.TCC", "com.apple.sharedfilelist",
            "CallHistoryDB", "Knowledge", "CloudDocs", "Dock", "iCloud",
            "Caches", "SyncServices", "MobileSync"
        ]

        for entry in entries {
            if Task.isCancelled { break }
            if systemDirs.contains(entry) { continue }
            if entry.hasPrefix("com.apple.") { continue }
            guard isOrphaned(entry, installed: installed) else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 5_000_000 { // > 5MB
                items.append(CleanableItem(
                    path: fullPath, sizeBytes: size, safetyLevel: .safe,
                    description: "App data for uninstalled app '\(entry)'. Safe to delete."
                ))
                total += size
            }
        }
    }

    private func scanCaches(installed: [InstalledApp], items: inout [CleanableItem], total: inout Int64) async {
        let path = ("~/Library/Caches" as NSString).expandingTildeInPath
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else { return }

        for entry in entries {
            if Task.isCancelled { break }
            if entry.hasPrefix("com.apple.") { continue }
            guard isOrphaned(entry, installed: installed) else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let result = await SizeCalculator.calculateSize(at: fullPath)
            if case .success(let size) = result, size > 5_000_000 { // > 5MB
                items.append(CleanableItem(
                    path: fullPath, sizeBytes: size, safetyLevel: .safe,
                    description: "Cache for uninstalled app '\(entry)'. Safe to delete."
                ))
                total += size
            }
        }
    }

    /// Scan home directory dotfiles that belong to known GUI apps.
    /// If the app is uninstalled, the dotfile is orphaned.
    private func scanOrphanedDotfiles(installed: [InstalledApp], items: inout [CleanableItem], total: inout Int64) async {
        // Map: dotfile name -> app names to look for in /Applications
        // Only include dotfiles that are clearly tied to a specific GUI app.
        // CLI tools (.nvm, .pyenv, .cargo) are NOT included because they don't have .app files.
        let dotfileToApp: [(dotfile: String, appNames: [String], description: String)] = [
            (".windsurf", ["Windsurf"], "Windsurf editor (by Codeium). Extensions, settings, workspace data."),
            (".codeium", ["Windsurf", "Codeium"], "Codeium AI assistant. Language models and chat history. Used by Windsurf and editor plugins."),
            (".cursor", ["Cursor"], "Cursor AI editor. Extensions, AI conversation history, workspace data."),
            (".vscode", ["Visual Studio Code", "Code"], "VS Code editor. Extensions, settings, workspace state."),
            (".trae", ["Trae"], "Trae editor (by ByteDance). Extensions and workspace data."),
            (".android", ["Android Studio"], "Android SDK tools, emulator data, debug keys."),
            (".docker", ["Docker", "OrbStack"], "Docker CLI config and context."),
            (".eclipse", ["Eclipse"], "Eclipse IDE workspace and plugins."),
            (".idea", ["IntelliJ IDEA", "WebStorm", "PyCharm", "GoLand", "PhpStorm", "CLion", "Rider", "DataGrip"], "JetBrains IDE settings and project data."),
            (".sublime-text", ["Sublime Text"], "Sublime Text editor data."),
            (".atom", ["Atom"], "Atom editor (discontinued). Extensions and settings."),
            (".hyper", ["Hyper"], "Hyper terminal data."),
            (".fig", ["Fig"], "Fig (now Amazon Q). Autocomplete data."),
            (".zed", ["Zed"], "Zed editor data and extensions."),
        ]

        let homePath = NSHomeDirectory()

        for entry in dotfileToApp {
            if Task.isCancelled { break }

            let dotfilePath = (homePath as NSString).appendingPathComponent(entry.dotfile)
            guard FileManager.default.fileExists(atPath: dotfilePath) else { continue }

            // Check if ANY of the associated apps are still installed
            let appInstalled = entry.appNames.contains { appName in
                installed.contains { $0.nameLowered.contains(appName.lowercased()) }
            }

            if appInstalled { continue } // App still installed, not orphaned

            let result = await SizeCalculator.calculateSize(at: dotfilePath)
            if case .success(let size) = result, size > 1_000_000 { // > 1MB
                let appList = entry.appNames.joined(separator: " / ")
                items.append(CleanableItem(
                    path: dotfilePath, sizeBytes: size, safetyLevel: .safe,
                    description: "\(entry.description)\n\n\(appList) is no longer installed. This folder is leftover data and safe to delete."
                ))
                total += size
            }
        }

        // Also check ~/Library/Preferences for orphaned plist files (usually small but many)
        // Skip this - plists are tiny and not worth the complexity
    }
}
