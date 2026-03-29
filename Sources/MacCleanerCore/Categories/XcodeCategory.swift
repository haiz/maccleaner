import Foundation

/// Xcode DerivedData — build artifacts that rebuild on demand.
public final class XcodeCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "Xcode DerivedData",
            icon: "hammer.fill",
            safetyLevel: .safe,
            scanPaths: [
                "~/Library/Developer/Xcode/DerivedData",
            ],
            itemDescription: "Xcode build artifacts. Rebuilds automatically when you next build a project."
        )
    }
}

/// Xcode Simulators — old runtimes that may not be needed.
public final class XcodeSimulatorsCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "Xcode Simulators",
            icon: "iphone",
            safetyLevel: .caution,
            scanPaths: [
                "~/Library/Developer/CoreSimulator/Caches",
            ],
            itemDescription: "iOS Simulator caches. Check which runtimes you need before deleting."
        )
    }
}

/// Xcode Archives — old app builds.
public final class XcodeArchivesCategory: FileBasedCategory {
    public init() {
        super.init(
            name: "Xcode Archives",
            icon: "archivebox.fill",
            safetyLevel: .caution,
            scanPaths: [
                "~/Library/Developer/Xcode/Archives",
            ],
            itemDescription: "Old Xcode build archives. Review before deleting if you need to debug past releases."
        )
    }
}
