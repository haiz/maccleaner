import Foundation

/// Time Machine local snapshots — scan-only in GUI.
/// Cleanup requires sudo: `sudo tmutil deletelocalsnapshots <date>`.
public final class TimeMachineCategory: ScannableCategory, @unchecked Sendable {
    public let name = "Time Machine"
    public let icon = "clock.arrow.circlepath"
    public let safetyLevel: SafetyLevel = .safe

    public init() {}

    public func scan() async -> ScanResult {
        // Use tmutil to list local snapshots and estimate size
        let snapshots = await listLocalSnapshots()

        guard !snapshots.isEmpty else {
            return ScanResult(
                categoryName: name,
                categoryIcon: icon,
                items: [],
                totalBytes: 0,
                safetyLevel: safetyLevel
            )
        }

        // Estimate size from purgeable space (macOS reports this via volume info)
        let purgeableBytes = await estimatePurgeableBytes()

        let item = CleanableItem(
            path: "/var/db/com.apple.TimeMachine",
            sizeBytes: purgeableBytes,
            safetyLevel: safetyLevel,
            description: "\(snapshots.count) local snapshot(s). Use CLI: sudo maccleaner clean --category timemachine"
        )

        return ScanResult(
            categoryName: name,
            categoryIcon: icon,
            items: purgeableBytes > 0 ? [item] : [],
            totalBytes: purgeableBytes,
            safetyLevel: safetyLevel
        )
    }

    // MARK: - Private

    private func listLocalSnapshots() async -> [String] {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            process.arguments = ["listlocalsnapshots", "/"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let snapshots = output.components(separatedBy: "\n")
                    .filter { $0.contains("com.apple.TimeMachine") }
                continuation.resume(returning: snapshots)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    private func estimatePurgeableBytes() async -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        ) else {
            return 0
        }
        let important = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        // Purgeable space is the difference between "important usage" capacity and raw available
        let purgeable = important - available
        return max(0, purgeable)
    }
}
