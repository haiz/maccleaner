import Foundation

/// iOS device backups — check if you still need old backups before deleting.
public final class IOSBackupCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "iOS Backups",
            icon: "iphone.gen3",
            safetyLevel: .caution,
            scanPaths: [
                "~/Library/Application Support/MobileSync/Backup",
            ],
            itemDescription: "iOS device backups. Check if you need old backups before deleting."
        )
    }
}
