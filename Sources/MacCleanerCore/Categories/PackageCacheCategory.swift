import Foundation

/// Package manager download caches in ~/Library/ locations.
/// NOTE: ~/.npm, ~/.gradle, ~/.cargo, ~/.pnpm-store are covered by HiddenDotfilesCategory.
/// ~/Library/Caches/pip and ~/Library/Caches/CocoaPods are covered by AppCacheCategory.
/// This category covers ONLY ~/Library/pnpm (not covered elsewhere).
public final class PackageCacheCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "Package Caches",
            icon: "shippingbox.fill",
            safetyLevel: .safe,
            scanPaths: [
                "~/Library/pnpm",
            ],
            itemDescription: "Package manager caches. Re-downloaded on next install."
        )
    }
}
