import Foundation

/// Application caches — ~/Library/Caches. Apps rebuild these on demand.
public final class AppCacheCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "App Caches",
            icon: "square.stack.3d.up.fill",
            safetyLevel: .safe,
            scanPaths: [
                "~/Library/Caches",
            ],
            itemDescription: "Application caches. Apps rebuild these automatically."
        )
    }
}
