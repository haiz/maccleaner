import Foundation

/// Hidden dotfiles in home directory — dev tool caches, version managers, etc.
/// Shows per-directory breakdown so users can identify the biggest offenders.
public final class HiddenDotfilesCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Dev Tool Data"
    public let icon = "eye.slash.fill"
    public let safetyLevel: SafetyLevel = .caution

    /// Known dotfile directories with descriptions and cleanup hints.
    private static let knownDotfiles: [(path: String, description: String)] = [
        ("~/.nvm", "Node version manager — old Node versions. Run `nvm ls` to review."),
        ("~/.codeium", "Codeium AI cache. Safe to clear, re-downloads on use."),
        ("~/.gradle", "Gradle build cache. Run `gradle cleanBuildCache` or delete."),
        ("~/.docker", "Docker CLI config + cache. Separate from Docker Desktop data."),
        ("~/.flair", "Flair NLP models. Delete unused models."),
        ("~/.pyenv", "Python version manager — old Python versions. Run `pyenv versions`."),
        ("~/.nuget", ".NET NuGet package cache. Run `dotnet nuget locals all --clear`."),
        ("~/.vscode", "VS Code extensions + data."),
        ("~/.npm", "npm cache. Run `npm cache clean --force`."),
        ("~/.cache", "General XDG cache directory. Usually safe to clear."),
        ("~/.cursor", "Cursor editor data."),
        ("~/.trae", "Trae editor data."),
        ("~/.android", "Android emulator + debug data."),
        ("~/.rustup", "Rust toolchain manager. Run `rustup toolchain list`."),
        ("~/.windsurf", "Windsurf editor data."),
        ("~/.cargo", "Rust cargo registry + build cache."),
        ("~/.cocoapods", "CocoaPods spec cache. Run `pod cache clean --all`."),
        ("~/.gem", "Ruby gem cache."),
        ("~/.local", "Local user binaries and data."),
        ("~/.ollama", "Ollama LLM models. Delete unused models."),
        ("~/.bun", "Bun runtime + cache."),
        ("~/.deno", "Deno runtime cache."),
    ]

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        for dotfile in Self.knownDotfiles {
            if Task.isCancelled { break }

            let expanded = (dotfile.path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }

            let result = await SizeCalculator.calculateSize(at: expanded)
            if case .success(let size) = result, size > 50_000_000 { // Only show > 50MB
                items.append(CleanableItem(
                    path: expanded,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    lastAccessed: SizeCalculator.lastAccessDate(at: expanded),
                    description: dotfile.description
                ))
                totalBytes += size
            }
        }

        // Also scan for unknown large dotfiles
        let homePath = NSHomeDirectory()
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: homePath) {
            let knownPaths = Set(Self.knownDotfiles.map { ($0.path as NSString).expandingTildeInPath })

            for entry in entries where entry.hasPrefix(".") {
                if Task.isCancelled { break }

                let fullPath = (homePath as NSString).appendingPathComponent(entry)
                guard !knownPaths.contains(fullPath) else { continue }

                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
                      isDir.boolValue else { continue }

                // Skip common small/system dotdirs
                let skip = [".Trash", ".ssh", ".gnupg", ".config", ".claude", ".git", ".zsh_sessions"]
                guard !skip.contains(entry) else { continue }

                let result = await SizeCalculator.calculateSize(at: fullPath)
                if case .success(let size) = result, size > 100_000_000 { // > 100MB for unknown
                    items.append(CleanableItem(
                        path: fullPath,
                        sizeBytes: size,
                        safetyLevel: .caution,
                        lastAccessed: SizeCalculator.lastAccessDate(at: fullPath),
                        description: "Unknown dotfile directory"
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
