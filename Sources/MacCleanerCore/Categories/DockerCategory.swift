import Foundation

/// Docker — uses `docker system df` for accurate reclaimable size,
/// `docker system prune -f` for safe cleanup (no --all by default).
public final class DockerCategory: CleanableCategory, @unchecked Sendable {
    public let name = "Docker"
    public let icon = "cube.fill"
    public let safetyLevel: SafetyLevel = .caution
    public let isIrreversible = true

    /// Whether to use --all flag (removes ALL images, not just dangling).
    public var deepClean: Bool = false

    public init() {}

    public func scan() async -> ScanResult {
        let containerPath = ("~/Library/Containers/com.docker.docker" as NSString).expandingTildeInPath

        // Check if Docker data directory exists
        guard FileManager.default.fileExists(atPath: containerPath) else {
            return ScanResult(
                categoryName: name,
                categoryIcon: icon,
                items: [],
                totalBytes: 0,
                error: ScanError("Docker not installed"),
                safetyLevel: safetyLevel
            )
        }

        // Get total directory size
        let totalResult = await SizeCalculator.calculateSize(at: containerPath)
        let totalBytes: Int64
        switch totalResult {
        case .success(let size): totalBytes = size
        case .failure: totalBytes = 0
        }

        // Try to get reclaimable size via docker system df
        let reclaimable = await dockerReclaimableBytes()

        let item = CleanableItem(
            path: containerPath,
            sizeBytes: totalBytes,
            safetyLevel: safetyLevel,
            description: reclaimable != nil
                ? "Docker data. \(ByteCountFormatter.string(fromByteCount: reclaimable!, countStyle: .file)) reclaimable."
                : "Docker data. Start Docker to see reclaimable size."
        )

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: [item],
            totalBytes: totalBytes,
            reclaimableBytes: reclaimable,
            safetyLevel: safetyLevel
        )
    }

    public func clean(items: [CleanableItem]) async -> CleanupReport {
        // Check if Docker is running
        guard await isDockerRunning() else {
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 0,
                bytesFreed: 0,
                errors: [CleanupError(path: "docker", message: "Docker is not running. Please start Docker Desktop first.")]
            )
        }

        var args = ["system", "prune", "-f"]
        if deepClean {
            args.append("--all")
            args.append("--volumes")
        }

        let result = await runProcess("/usr/local/bin/docker", arguments: args)

        switch result {
        case .success(let output):
            // Parse "Total reclaimed space: X.XX GB" from output
            let bytesFreed = parseReclaimedBytes(from: output)
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 1,
                bytesFreed: bytesFreed
            )
        case .failure(let error):
            return CleanupReport(
                categoryName: name,
                itemsCleaned: 0,
                bytesFreed: 0,
                errors: [CleanupError(path: "docker", message: error.localizedDescription)]
            )
        }
    }

    // MARK: - Private

    private func isDockerRunning() async -> Bool {
        let result = await runProcess("/usr/local/bin/docker", arguments: ["info"])
        if case .success = result { return true }
        return false
    }

    private func dockerReclaimableBytes() async -> Int64? {
        let result = await runProcess("/usr/local/bin/docker", arguments: ["system", "df", "--format", "{{.Reclaimable}}"])
        guard case .success(let output) = result else { return nil }

        // Parse lines like "1.234GB" and sum them
        var total: Int64 = 0
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            total += parseByteString(line.trimmingCharacters(in: .whitespaces))
        }
        return total > 0 ? total : nil
    }

    private func parseReclaimedBytes(from output: String) -> Int64 {
        // Look for "Total reclaimed space: 1.234GB"
        guard let range = output.range(of: "Total reclaimed space: ") else { return 0 }
        let sizeStr = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseByteString(sizeStr)
    }

    private func parseByteString(_ str: String) -> Int64 {
        let cleaned = str.replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespaces)

        let multipliers: [(String, Double)] = [
            ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("B", 1),
        ]
        for (suffix, multiplier) in multipliers {
            if cleaned.hasSuffix(suffix) {
                let numStr = cleaned.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
                if let num = Double(numStr) {
                    return Int64(num * multiplier)
                }
            }
        }
        return 0
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
                        NSError(domain: "DockerCategory", code: Int(process.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: output])
                    ))
                }
            } catch {
                continuation.resume(returning: .failure(error))
            }
        }
    }
}
