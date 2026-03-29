import Foundation

/// Homebrew — uses `brew --cache` for cache path, `brew cleanup --prune=all` for cleanup.
public final class HomebrewCategory: CleanableCategory, @unchecked Sendable {
    public let name = "Homebrew"
    public let icon = "mug.fill"
    public let safetyLevel: SafetyLevel = .caution
    public let isIrreversible = true

    public init() {}

    public func scan() async -> ScanResult {
        // Detect Homebrew installation
        let brewPath = findBrewPath()
        guard let brewPath else {
            return ScanResult(
                categoryName: name,
                categoryIcon: icon,
                items: [],
                totalBytes: 0,
                error: ScanError("Homebrew not installed"),
                safetyLevel: safetyLevel
            )
        }

        // Get cache directory via `brew --cache`
        let cacheResult = await runProcess(brewPath, arguments: ["--cache"])
        let cachePath: String
        switch cacheResult {
        case .success(let output):
            cachePath = output.trimmingCharacters(in: .whitespacesAndNewlines)
        case .failure:
            cachePath = "/opt/homebrew/cache"
        }

        // Calculate cache size
        let cacheSize = await SizeCalculator.calculateSize(at: cachePath)
        let totalBytes: Int64
        switch cacheSize {
        case .success(let size): totalBytes = size
        case .failure: totalBytes = 0
        }

        guard totalBytes > 0 else {
            return ScanResult(
                categoryName: name,
                categoryIcon: icon,
                items: [],
                totalBytes: 0,
                safetyLevel: safetyLevel
            )
        }

        let item = CleanableItem(
            path: cachePath,
            sizeBytes: totalBytes,
            safetyLevel: safetyLevel,
            description: "Homebrew download cache. Cleared via `brew cleanup`."
        )

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: [item],
            totalBytes: totalBytes,
            safetyLevel: safetyLevel
        )
    }

    public func clean(items: [CleanableItem]) async -> CleanupReport {
        guard let brewPath = findBrewPath() else {
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 0,
                bytesFreed: 0,
                errors: [CleanupError(path: "brew", message: "Homebrew not found")]
            )
        }

        // Get cache size before cleanup
        let beforeSize: Int64
        if let firstItem = items.first {
            beforeSize = firstItem.sizeBytes
        } else {
            beforeSize = 0
        }

        let result = await runProcess(brewPath, arguments: ["cleanup", "--prune=all"])

        switch result {
        case .success:
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 1,
                bytesFreed: beforeSize
            )
        case .failure(let error):
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 0,
                bytesFreed: 0,
                errors: [CleanupError(path: "brew", message: error.localizedDescription)]
            )
        }
    }

    // MARK: - Private

    private func findBrewPath() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func runProcess(_ path: String, arguments: [String]) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: .success(output))
                } else {
                    continuation.resume(returning: .failure(
                        NSError(domain: "HomebrewCategory", code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: output])
                    ))
                }
            } catch {
                continuation.resume(returning: .failure(error))
            }
        }
    }
}
