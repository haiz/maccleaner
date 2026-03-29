import Foundation

/// APFS volume breakdown from `diskutil apfs list`.
public struct APFSVolume: Sendable {
    public let name: String
    public let role: String
    public let consumedBytes: Int64
}

public enum APFSVolumeScanner {

    /// Parse `diskutil apfs list` to get all APFS volume sizes.
    public static func getVolumes() async -> [APFSVolume] {
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
                let volumes = parseVolumes(from: output)
                continuation.resume(returning: volumes)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    private static func parseVolumes(from output: String) -> [APFSVolume] {
        var volumes: [APFSVolume] = []
        let lines = output.components(separatedBy: "\n")

        var currentName: String?
        var currentRole: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse: "Name:  Macintosh HD (Case-insensitive)"
            if trimmed.hasPrefix("Name:") {
                let value = trimmed.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces)
                currentName = value.components(separatedBy: " (").first ?? value
            }

            // Parse: "APFS Volume Disk (Role):   disk3s5 (Data)"
            if trimmed.contains("(Role)") {
                if let parenStart = trimmed.lastIndex(of: "("),
                   let parenEnd = trimmed.lastIndex(of: ")") {
                    currentRole = String(trimmed[trimmed.index(after: parenStart)..<parenEnd])
                }
            }

            // Parse: "Capacity Consumed:  12459171840 B (12.5 GB)"
            if trimmed.hasPrefix("Capacity Consumed:") {
                let value = trimmed.replacingOccurrences(of: "Capacity Consumed:", with: "").trimmingCharacters(in: .whitespaces)
                let numStr = value.prefix(while: { $0.isNumber })
                if let bytes = Int64(numStr), let name = currentName, let role = currentRole {
                    volumes.append(APFSVolume(name: name, role: role, consumedBytes: bytes))
                }
                currentName = nil
                currentRole = nil
            }
        }

        return volumes.sorted { $0.consumedBytes > $1.consumedBytes }
    }
}
