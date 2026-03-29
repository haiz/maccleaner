import Foundation

/// System-level storage consumers: VM swap, Preboot, sleepimage, APFS snapshots.
/// These are normally invisible but can consume 30-50 GB.
/// Scan-only in GUI — cleanup requires restart or sudo commands.
public final class SystemHealthCategory: ScannableCategory, @unchecked Sendable {
    public let name = "System Overhead"
    public let icon = "memorychip"
    public let safetyLevel: SafetyLevel = .caution

    public init() {}

    public func scan() async -> ScanResult {
        var items: [CleanableItem] = []
        var totalBytes: Int64 = 0

        // 1. VM swap usage
        let swapInfo = await getSwapUsage()
        if swapInfo.used > 0 {
            items.append(CleanableItem(
                path: "/var/vm",
                sizeBytes: swapInfo.used,
                safetyLevel: .caution,
                description: "VM swap (\(formatGB(swapInfo.used)) of \(formatGB(swapInfo.total)) allocated). Fix: restart Mac to reset swap to 0."
            ))
            totalBytes += swapInfo.used
        }

        // 2. Preboot volume
        let prebootSize = await getVolumeConsumed(role: "Preboot")
        if prebootSize > 2_000_000_000 { // Only flag if > 2GB (normal is ~1-3GB)
            items.append(CleanableItem(
                path: "/System/Volumes/Preboot",
                sizeBytes: prebootSize,
                safetyLevel: .caution,
                description: prebootSize > 5_000_000_000
                    ? "Preboot volume is abnormally large (\(formatGB(prebootSize))). Normal: 1-3 GB. Run: sudo diskutil apfs updatePreboot disk3s5"
                    : "Preboot volume (\(formatGB(prebootSize))). Contains boot assets and FileVault data."
            ))
            totalBytes += prebootSize
        }

        // 3. sleepimage
        let sleepPath = "/var/vm/sleepimage"
        if FileManager.default.fileExists(atPath: sleepPath) {
            let result = await SizeCalculator.calculateSize(at: sleepPath)
            if case .success(let size) = result, size > 0 {
                items.append(CleanableItem(
                    path: sleepPath,
                    sizeBytes: size,
                    safetyLevel: .caution,
                    description: "Hibernation image. Disable: sudo pmset hibernatemode 0 && sudo rm /var/vm/sleepimage"
                ))
                // Don't add to total — already counted in swap
            }
        }

        // 4. APFS snapshots
        let snapshotInfo = await getSnapshotInfo()
        if !snapshotInfo.isEmpty {
            // Estimate snapshot size from purgeable space
            let purgeableBytes = await getPurgeableSpace()
            if purgeableBytes > 1_000_000_000 {
                items.append(CleanableItem(
                    path: "/APFS-snapshots",
                    sizeBytes: purgeableBytes,
                    safetyLevel: .caution,
                    description: "\(snapshotInfo.count) APFS snapshot(s). Purgeable space: \(formatGB(purgeableBytes)). macOS auto-frees this when needed."
                ))
                totalBytes += purgeableBytes
            }
        }

        // 5. Recovery volume
        let recoverySize = await getVolumeConsumed(role: "Recovery")
        if recoverySize > 0 {
            items.append(CleanableItem(
                path: "/System/Volumes/Recovery",
                sizeBytes: recoverySize,
                safetyLevel: .caution,
                description: "Recovery partition. Cannot be reduced."
            ))
            totalBytes += recoverySize
        }

        // 6. macOS System volume
        let systemSize = await getVolumeConsumed(role: "System")
        if systemSize > 0 {
            items.append(CleanableItem(
                path: "/System/Volumes/Data",
                sizeBytes: systemSize,
                safetyLevel: .caution,
                description: "macOS system files."
            ))
            totalBytes += systemSize
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

    // MARK: - Private

    private func getSwapUsage() async -> (total: Int64, used: Int64) {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
            process.arguments = ["vm.swapusage"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                // Parse: "vm.swapusage: total = 35840.00M  used = 34904.44M  free = 935.56M"
                let total = parseMB(from: output, key: "total")
                let used = parseMB(from: output, key: "used")
                continuation.resume(returning: (total, used))
            } catch {
                continuation.resume(returning: (0, 0))
            }
        }
    }

    private func parseMB(from output: String, key: String) -> Int64 {
        guard let range = output.range(of: "\(key) = ") else { return 0 }
        let rest = String(output[range.upperBound...])
        let numStr = rest.prefix(while: { $0.isNumber || $0 == "." })
        guard let mb = Double(numStr) else { return 0 }
        return Int64(mb * 1_048_576) // MB to bytes
    }

    private func getVolumeConsumed(role: String) async -> Int64 {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["apfs", "list"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // Find the role line, then the Capacity Consumed line after it
                let lines = output.components(separatedBy: "\n")
                var foundRole = false
                for line in lines {
                    if line.contains("Role"), line.contains(role) {
                        foundRole = true
                    }
                    if foundRole && line.contains("Capacity Consumed") {
                        // Parse "Capacity Consumed:  12459171840 B (12.5 GB)"
                        if let numStart = line.range(of: "Consumed:")?.upperBound {
                            let rest = line[numStart...].trimmingCharacters(in: .whitespaces)
                            let numStr = rest.prefix(while: { $0.isNumber })
                            if let bytes = Int64(numStr) {
                                continuation.resume(returning: bytes)
                                return
                            }
                        }
                        break
                    }
                }
                continuation.resume(returning: 0)
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }

    private func getSnapshotInfo() async -> [String] {
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
                    .filter { !$0.isEmpty && $0 != "Snapshots for volume group containing disk /:" }
                continuation.resume(returning: snapshots)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    private func getPurgeableSpace() async -> Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        ) else { return 0 }
        let important = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        return max(0, important - available)
    }

    private func formatGB(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
