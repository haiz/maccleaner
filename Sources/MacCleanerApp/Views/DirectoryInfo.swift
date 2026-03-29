import Foundation

/// Knowledge base of well-known directories and what created them.
/// Each description follows the format:
///   Line 1: What is this? (plain language)
///   Line 2: Why is it big?
///   Line 3: Can I delete it? (SAFE / CAUTION / DO NOT DELETE)
///   Line 4: How to clean (exact command or action)
enum DirectoryInfo {
    static func description(for path: String) -> String? {
        let name = (path as NSString).lastPathComponent
        let lowered = name.lowercased()

        if let fullMatch = fullPathDescriptions[path] { return fullMatch }
        if let nameMatch = nameDescriptions[lowered] ?? nameDescriptions[name] { return nameMatch }
        for (prefix, desc) in prefixDescriptions {
            if lowered.hasPrefix(prefix) { return desc }
        }
        return nil
    }

    // MARK: - Full path matches

    private static let fullPathDescriptions: [String: String] = [
        "/var/vm":
            """
            macOS swap files. When your 16 GB RAM runs out, macOS moves data from memory to disk so apps can keep running.

            Why so big? You're running many apps at once (Chrome, VS Code, Docker, Slack...). macOS needs 35+ GB of disk as virtual memory.

            Can I delete it? Not directly. Restarting your Mac resets swap back to near zero. Closing unused apps reduces swap usage.

            How to fix: Restart Mac. Swap drops from ~35 GB to ~2 GB.
            """,
        "/var/vm/sleepimage":
            """
            Hibernation image. A copy of your RAM saved to disk when your Mac enters deep sleep. This lets the Mac power off completely while preserving your open apps.

            Why so big? It matches your RAM size (16 GB).

            Can I delete it? Yes, if you don't need hibernation.

            How to fix:
            sudo pmset hibernatemode 0
            sudo rm /var/vm/sleepimage
            (Saves ~2 GB. Mac still sleeps normally, just won't hibernate.)
            """,
        "/System/Volumes/Preboot":
            """
            macOS boot volume. Contains FileVault encryption keys, firmware, and boot assets needed to start your Mac.

            Why so big? Normally 1-3 GB. If larger than 5 GB, old macOS updates may not have been cleaned up.

            Can I delete it? DO NOT DELETE. This is required to boot your Mac.

            If abnormally large (> 10 GB): Try sudo diskutil apfs updatePreboot disk3s5
            """,
        "/System/Volumes/Recovery":
            """
            macOS Recovery partition. Used to reinstall macOS if something goes wrong.

            Size: ~1.3 GB (normal).

            Can I delete it? NEVER. This is your safety net when the Mac has serious issues.
            """,
        "/usr/local":
            """
            Local binaries and libraries. On Intel Macs, this is where Homebrew installs packages.

            Why so big? Each Homebrew package adds binaries and dependencies here.

            Can I delete it? CAUTION. Only remove things through Homebrew: brew uninstall <package>

            See what's installed: brew list --formula
            """,
        "/opt/homebrew":
            """
            Homebrew package manager (Apple Silicon Mac). Contains all packages you installed via "brew install".

            Why so big? Each formula installs binaries + dependencies. They accumulate over time.

            Can I delete it? Clean old versions: brew cleanup --prune=all
            See what's installed: brew list --formula
            Remove unused packages: brew uninstall <package>
            """,
        "/Library/Developer":
            """
            Xcode command line tools, SDK platforms, and Apple toolchains.

            Why so big? Each Xcode version installs new SDKs (iOS, macOS, watchOS). Old versions are not auto-removed.

            Can I delete it? Yes, you can remove old SDKs. Open Xcode > Settings > Platforms > delete old platforms.
            Or: sudo rm -rf /Library/Developer/CommandLineTools (then reinstall: xcode-select --install)
            """,
        "/Library/Frameworks":
            """
            System frameworks installed by applications (Python.framework, Mono, .NET, etc).

            Why so big? Each framework may contain multiple versions.

            Can I delete it? CAUTION. Only delete frameworks for apps you've already uninstalled. Example: Python.framework can be removed if you use pyenv instead.
            """,
    ]

    // MARK: - Directory name matches

    private static let nameDescriptions: [String: String] = [
        // === Dev tools ===
        ".nvm":
            """
            Node Version Manager. Manages multiple Node.js versions on your machine.

            Why so big? Each Node.js version is 100-500 MB. If you have 10 versions installed, that's 5-10 GB.

            Can I delete it? SAFE to remove old versions you no longer use.

            How to clean:
            1. List versions: nvm ls
            2. Remove old ones: nvm uninstall 16  (keep the version you're currently using)
            """,
        ".codeium":
            """
            Codeium AI coding assistant. Contains downloaded language models and cache.

            Why so big? AI models can be 5-10 GB.

            Can I delete it? SAFE. It will re-download what it needs when you open Codeium.

            How to clean: Delete the entire ~/.codeium folder.
            """,
        ".gradle":
            """
            Gradle build cache. Used by Java, Android, and Kotlin projects.

            Why so big? Stores build artifacts, downloaded dependencies, and daemon logs. Grows over time.

            Can I delete it? SAFE. Builds will be slower the first time, but everything re-downloads automatically.

            How to clean: rm -rf ~/.gradle/caches  (keep ~/.gradle/gradle.properties)
            Or run: ./gradlew cleanBuildCache
            """,
        ".docker":
            """
            Docker CLI configuration and context. This is SEPARATE from Docker Desktop data (which lives in ~/Library/Containers).

            Why so big? Contains Docker contexts, build cache, and config files.

            Can I delete it? CAUTION. Deleting this removes your Docker login sessions and config. Back up first.
            """,
        ".flair":
            """
            Flair NLP library. Contains pre-trained AI models for natural language processing.

            Why so big? Each model can be 1-3 GB.

            Can I delete it? SAFE. Delete models you don't use. They re-download when needed.

            How to clean: Browse ~/.flair and delete unused model files.
            """,
        ".pyenv":
            """
            Python Version Manager. Contains multiple Python installations.

            Why so big? Each Python version is 200-500 MB.

            Can I delete it? SAFE to remove old versions.

            How to clean:
            1. List versions: pyenv versions
            2. Remove old ones: pyenv uninstall 3.9.7  (keep the version you're using)
            """,
        ".nuget":
            """
            .NET NuGet package cache. Libraries for C# and .NET development.

            Why so big? Every package and its dependencies are cached here.

            Can I delete it? SAFE. Packages re-download when you build.

            How to clean: dotnet nuget locals all --clear
            """,
        ".npm":
            """
            npm download cache. Cached copies of every npm package you've ever installed.

            Why so big? Each "npm install" caches packages here for faster future installs.

            Can I delete it? SAFE. Running "npm install" will re-download from the internet.

            How to clean: npm cache clean --force
            """,
        ".cache":
            """
            XDG cache directory. Shared by many tools: pip, yarn, Hugging Face models, etc.

            Why so big? Multiple tools dump their caches here over time.

            Can I delete it? USUALLY SAFE. Check subdirectories first.

            How to clean: Browse subfolders first: ls ~/.cache/ then delete specific ones.
            """,
        ".cargo":
            """
            Rust cargo registry and build cache.

            Why so big? Downloaded crates (Rust libraries) and compiled build artifacts.

            Can I delete it? Cache is SAFE to delete. Registry re-downloads when you build.

            How to clean: cargo clean (in a project) or rm -rf ~/.cargo/registry/cache
            """,
        ".rustup":
            """
            Rust toolchain manager. Contains installed Rust compiler versions.

            Why so big? Each toolchain (stable, nightly, beta) is 500 MB - 1 GB.

            Can I delete it? SAFE to remove toolchains you don't use.

            How to clean:
            1. List: rustup toolchain list
            2. Remove: rustup toolchain remove nightly-2024-01-01
            """,
        ".cocoapods":
            """
            CocoaPods. iOS/macOS dependency manager. Contains spec repo and downloaded pod cache.

            Can I delete it? SAFE. Running "pod install" will re-download everything.

            How to clean: pod cache clean --all
            """,
        ".gem":
            """
            Ruby gems cache. Contains installed Ruby libraries.

            Can I delete it? SAFE to remove old versions: gem cleanup
            """,
        ".vscode":
            """
            VS Code. Contains extensions, settings, workspace state, and terminal history.

            Why so big? Extensions (especially AI extensions) can consume several GB.

            Can I delete it? CAUTION. Deleting this removes all your VS Code settings and extensions. Back up first.
            """,
        ".cursor":
            """
            Cursor AI Editor. Contains AI models, extensions, and workspace data.

            Why so big? AI model cache and conversation history can grow to several GB.

            Can I delete it? CAUTION. Deleting removes your chat history and settings.
            """,
        ".windsurf":
            """
            Windsurf Editor (by Codeium). Contains extensions and AI data.

            Can I delete it? CAUTION. Same considerations as VS Code.
            """,
        ".trae":
            """
            Trae Editor (by ByteDance). Contains extensions and workspace data.

            Can I delete it? CAUTION. Same considerations as VS Code.
            """,
        ".android":
            """
            Android SDK tools: debug bridge (adb), emulator data, and device keys.

            Why so big? Emulator system images can be several GB each.

            Can I delete it? SAFE to remove old emulator images. Manage via Android Studio > SDK Manager.
            """,
        ".ollama":
            """
            Ollama. Runs AI models (LLMs) locally on your Mac. Each model is 2-8 GB.

            Why so big? Every model you've pulled (llama, mistral, codellama...) is stored as a large file.

            Can I delete it? SAFE to remove models you don't use.

            How to clean:
            1. List models: ollama list
            2. Remove: ollama rm llama2  (it will re-download if you need it later)
            """,
        ".bun":
            """
            Bun. A fast JavaScript runtime and package manager.

            Can I delete it? SAFE to clear cache: rm -rf ~/.bun/install/cache
            """,
        ".deno":
            """
            Deno. A JavaScript/TypeScript runtime. Caches downloaded modules.

            Can I delete it? SAFE. Modules re-download automatically: deno cache --reload
            """,
        "node_modules":
            """
            JavaScript project dependencies. Contains all libraries a project needs to run.

            Why so big? A typical React/Next.js project has 200-500 MB of node_modules. With 10 projects, that's 5 GB.

            Can I delete it? COMPLETELY SAFE. Run "npm install" or "pnpm install" in the project to restore.

            How to clean: Just delete this folder. When you need to work on the project again, run npm install.
            """,
        "deriveddata":
            """
            Xcode build artifacts. Automatically rebuilt every time you compile a project.

            Can I delete it? COMPLETELY SAFE. Xcode rebuilds everything from scratch.

            How to clean: Delete this folder, or in Xcode: Settings > Locations > Derived Data > Delete
            """,

        // === App containers ===
        "com.docker.docker":
            """
            Docker Desktop. Contains all your Docker images, containers, and volumes.

            Why so big? Each Docker image (node, postgres, nginx...) is 100 MB - 2 GB. They add up fast.

            Can I delete it? DO NOT delete this folder directly! It will corrupt Docker.

            How to clean: Open Docker Desktop > Settings > Resources > Clean/Purge data
            Or run: docker system prune -f  (removes unused images)
            """,
        "com.tinyspeck.slackmacgap":
            """
            Slack desktop app. Contains message cache, downloaded files, and media.

            Why so big? File attachments, images, and message cache accumulate over time.

            Can I delete it? CAUTION. Deleting removes offline cache. Restart Slack to re-download.
            """,
        "com.microsoft.teams2":
            """
            Microsoft Teams. Contains meeting recordings, cache, and offline data.

            Can I delete it? CAUTION. Deleting removes offline data. Teams re-downloads when needed.
            """,
        "com.apple.geod":
            """
            Apple Maps. Cached map tiles, routing data, and searched locations.

            Can I delete it? SAFE. Maps re-downloads data as you use it.
            """,
        "com.apple.mediaanalysisd":
            """
            Apple Photos AI. Face recognition and object detection models for your photo library.

            Why so big? Machine learning models and analysis cache.

            Can I delete it? SAFE, but macOS will re-analyze all your photos (takes time).
            """,

        // === Application Support ===
        "cursor":
            """
            Cursor AI Editor data. AI conversation history, extensions, and workspace state.

            Why so big? AI conversation cache and extension data grow over time.

            Can I delete it? CAUTION. You'll lose your AI chat history.
            """,
        "claude":
            """
            Claude desktop app. Contains conversation history and local cache.

            Why so big? Each conversation is saved locally.

            Can I delete it? CAUTION. You'll lose local chat history. But conversations are still on claude.ai.
            """,
        "google":
            """
            Google Chrome. Profile data including history, bookmarks, extensions, cache, and saved passwords.

            Why so big? Web page cache, extension data, and offline data accumulate over time.

            Can I delete it? CAUTION. Clean cache: Chrome > Settings > Clear browsing data.
            DO NOT delete the entire folder (you'll lose bookmarks and passwords).
            """,
        "zalodata":
            """
            Zalo messenger. Contains message history, photos, videos sent and received.

            Why so big? Media files (photos, videos) take up the most space.

            Can I delete it? CAUTION. You'll lose offline message history. Delete old media within the Zalo app.
            """,
        "code":
            """
            VS Code data. Extensions, workspace state, settings sync, and terminal history.

            Why so big? Extensions (especially AI extensions) and workspace cache.

            Can I delete it? CAUTION. Clean up: VS Code > Command Palette > "Clear Editor History"
            """,
        "discord":
            """
            Discord desktop. Message cache, media, and voice data.

            Can I delete it? SAFE to clear cache. Discord re-downloads data from the server.
            """,
        "postman":
            """
            Postman API client. Collections, environments, and request history.

            Can I delete it? CAUTION. If you have a Postman account, data is synced. If not, you'll lose your collections.
            """,
    ]

    // MARK: - Prefix pattern matches

    private static let prefixDescriptions: [(String, String)] = [
        ("com.apple.",
            """
            Apple system service data. Internal macOS component.

            Can I delete it? USUALLY NOT RECOMMENDED. macOS will recreate it, but you may lose some settings.
            """),
        ("com.google.",
            """
            Google app data (Chrome, Drive, or another Google app).

            Can I delete it? CAUTION. Clean up through the app itself rather than deleting directly.
            """),
        ("com.microsoft.",
            """
            Microsoft app data (Teams, Office, OneDrive, etc).

            Can I delete it? CAUTION. Clean up through the app itself rather than deleting directly.
            """),
    ]
}
