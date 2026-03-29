import Foundation

/// User logs — ~/Library/Logs. Rotated automatically by the system.
public final class UserLogsCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "User Logs",
            icon: "doc.text.fill",
            safetyLevel: .safe,
            scanPaths: [
                "~/Library/Logs",
            ],
            itemDescription: "Application and system logs. Rotated automatically."
        )
    }
}
