import SwiftUI
import MacCleanerCore

// MARK: - Tier definitions

enum CleanTier: String, CaseIterable {
    case quick = "Quick Clean"
    case deep = "Deep Clean"
    case expert = "Expert Clean"

    var icon: String {
        switch self {
        case .quick: return "hare.fill"
        case .deep: return "wrench.and.screwdriver.fill"
        case .expert: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .quick: return .green
        case .deep: return .blue
        case .expert: return .orange
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Caches, build artifacts, logs"
        case .deep: return "Quick + dev tools, old versions"
        case .expert: return "Deep + app data, Docker images"
        }
    }

    var riskLabel: String {
        switch self {
        case .quick: return "Zero risk. Everything auto-regenerates. Goes to Trash."
        case .deep: return "Some irreversible (Homebrew). Dev tools rebuild on demand."
        case .expert: return "Includes irreversible cleanups. Review details first."
        }
    }

    /// Category names included in each tier.
    var categoryNames: Set<String> {
        switch self {
        case .quick:
            // ONLY items that are 100% auto-regenerated with zero user action,
            // OR orphaned data from uninstalled apps.
            // Everything goes to Trash (recoverable).
            return [
                "App Caches", "Package Caches", "Xcode DerivedData",
                "User Logs", "node_modules", "Uninstalled App Leftovers"
            ]
        case .deep:
            var names = CleanTier.quick.categoryNames
            // Dev artifacts that rebuild on demand. Some are irreversible (Homebrew).
            names.formUnion([
                "Dev Tool Data", "Xcode Simulators", "Xcode Archives",
                "Homebrew"
            ])
            return names
        case .expert:
            var names = CleanTier.deep.categoryNames
            // User data and irreversible cleanups. Review before deleting.
            names.formUnion([
                "App Support Data", "Large App Data",
                "Android SDK", "iOS Backups", "Docker"
            ])
            // NOTE: Downloads intentionally excluded. User files should never
            // be in a batch cleanup. Use Finder to review Downloads manually.
            return names
        }
    }
}

// MARK: - CleanAllView

struct CleanAllView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: CleanTier = .quick
    @State private var showDetails = false
    @State private var customOverrides: Set<String> = [] // Items toggled on/off from default
    @State private var isCleaning = false
    @State private var reports: [CleanupReport] = []
    @State private var isDone = false

    private var cleanableResults: [(result: ScanResult, category: any CleanableCategory)] {
        viewModel.nonEmptyResults.compactMap { result in
            guard let cat = viewModel.executor.findCleanableCategory(named: result.categoryName),
                  !result.items.isEmpty else { return nil }
            return (result, cat)
        }
        .sorted { $0.result.effectiveReclaimableBytes > $1.result.effectiveReclaimableBytes }
    }

    /// Categories that will be cleaned with current tier + overrides.
    private var effectiveCategories: Set<String> {
        selectedTier.categoryNames.symmetricDifference(customOverrides)
    }

    private var effectiveResults: [(result: ScanResult, category: any CleanableCategory)] {
        cleanableResults.filter { effectiveCategories.contains($0.result.categoryName) }
    }

    private var effectiveBytes: Int64 {
        effectiveResults.reduce(0) { $0 + $1.result.effectiveReclaimableBytes }
    }

    private func bytesForTier(_ tier: CleanTier) -> Int64 {
        cleanableResults
            .filter { tier.categoryNames.contains($0.result.categoryName) }
            .reduce(0) { $0 + $1.result.effectiveReclaimableBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isDone {
                completionView
            } else {
                selectionView
            }
        }
        .frame(width: 600, height: 650)
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Clean All")
                    .font(.title.bold())
                Text("Choose cleanup level. Expand for details.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 3 Tier buttons
                    ForEach(CleanTier.allCases, id: \.rawValue) { tier in
                        tierButton(tier)
                    }

                    // Expandable detail
                    if showDetails {
                        detailSection
                    }

                    // System Actions (for APFS stuff)
                    systemActionsSection
                }
                .padding(20)
            }

            Divider()

            // Action bar
            actionBar
        }
    }

    private func tierButton(_ tier: CleanTier) -> some View {
        let isSelected = selectedTier == tier
        let bytes = bytesForTier(tier)
        let sizeStr = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)

        return Button(action: {
            withAnimation(.spring(duration: 0.2)) {
                selectedTier = tier
                customOverrides = []
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: tier.icon)
                    .font(.title2)
                    .foregroundStyle(tier.color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tier.color.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(tier.rawValue)
                            .font(.headline)
                        if tier == .quick {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                                .foregroundStyle(.green)
                        }
                    }
                    Text(tier.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tier.riskLabel)
                        .font(.caption2)
                        .foregroundStyle(tier == .expert ? .orange : .green)
                }

                Spacer()

                Text(sizeStr)
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(bytes > 10_000_000_000 ? .red : .primary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? tier.color : .secondary.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tier.color.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? tier.color.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details (\(effectiveCategories.count) categories)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(cleanableResults, id: \.result.categoryName) { item in
                let isInTier = selectedTier.categoryNames.contains(item.result.categoryName)
                let isEnabled = effectiveCategories.contains(item.result.categoryName)
                let sizeStr = ByteCountFormatter.string(fromByteCount: item.result.effectiveReclaimableBytes, countStyle: .file)

                DisclosureGroup {
                    // Show sub-items (folders that will be cleaned)
                    ForEach(item.result.items.prefix(20), id: \.id) { subItem in
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 12)

                            Text(URL(fileURLWithPath: subItem.path).lastPathComponent)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(subItem.formattedSize)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 28)
                    }
                    if item.result.items.count > 20 {
                        Text("and \(item.result.items.count - 20) more...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 28)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Button(action: {
                            if customOverrides.contains(item.result.categoryName) {
                                customOverrides.remove(item.result.categoryName)
                            } else {
                                customOverrides.insert(item.result.categoryName)
                            }
                        }) {
                            Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isEnabled ? (isInTier ? selectedTier.color : .orange) : .secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)

                        Image(systemName: item.result.categoryIcon)
                            .foregroundStyle(item.result.safetyLevel == .safe ? .green : .orange)
                            .frame(width: 16)

                        Text(item.result.categoryName)
                            .font(.caption)
                            .lineLimit(1)

                        Text("(\(item.result.items.count) items)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        if item.category.isIrreversible {
                            Text("Irreversible")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        Text(sizeStr)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .opacity(isEnabled ? 1.0 : 0.5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - System Actions

    private var systemActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Actions (reduce APFS overhead)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            systemActionCard(
                icon: "arrow.clockwise",
                title: "Restart Mac",
                subtitle: "Free VM swap (~35 GB). No data loss.",
                actionLabel: nil,
                color: .blue
            )

            systemActionCard(
                icon: "clock.arrow.circlepath",
                title: "Delete Time Machine Snapshots",
                subtitle: "Free local snapshots. Requires sudo.",
                actionLabel: "Copy command",
                color: .purple
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("sudo tmutil deletelocalsnapshots /", forType: .string)
            }

            systemActionCard(
                icon: "iphone",
                title: "Remove old iOS Simulators",
                subtitle: "iOS 18.0 Simulator (~8 GB). Tai lai khi can.",
                actionLabel: "Copy command",
                color: .orange
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("xcrun simctl runtime delete all", forType: .string)
            }

            systemActionCard(
                icon: "memorychip",
                title: "Purge system cache",
                subtitle: "Free purgeable space. Requires sudo.",
                actionLabel: "Copy command",
                color: .green
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("sudo purge", forType: .string)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func systemActionCard(
        icon: String,
        title: String,
        subtitle: String,
        actionLabel: String?,
        color: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.bold())
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            if let label = actionLabel, let action = action {
                Button(label) { action() }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                let sizeStr = ByteCountFormatter.string(fromByteCount: effectiveBytes, countStyle: .file)
                Text(sizeStr + " will be freed")
                    .font(.headline)
                    .foregroundStyle(effectiveBytes > 10_000_000_000 ? .red : .primary)

                Button(showDetails ? "Hide details" : "Show details") {
                    withAnimation { showDetails.toggle() }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button(isCleaning ? "Cleaning..." : "Start Clean") {
                Task { await performCleanAll() }
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedTier.color)
            .disabled(effectiveCategories.isEmpty || isCleaning)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()

            let totalFreed = reports.reduce(Int64(0)) { $0 + $1.bytesFreed }
            let totalErrors = reports.reduce(0) { $0 + $1.errors.count }

            Image(systemName: totalErrors > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(totalErrors > 0 ? .orange : .green)

            Text("Cleanup Complete!")
                .font(.title.bold())

            Text(ByteCountFormatter.string(fromByteCount: totalFreed, countStyle: .file) + " freed")
                .font(.title2)
                .foregroundStyle(.green)

            if totalErrors > 0 {
                Text("\(totalErrors) \(totalErrors == 1 ? "error" : "errors") occurred")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("Some folders are in use by running apps. This is normal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(reports, id: \.categoryName) { report in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: report.hasErrors ? "exclamationmark.circle" : "checkmark.circle")
                                    .foregroundStyle(report.hasErrors ? .orange : .green)
                                Text(report.categoryName)
                                Spacer()
                                Text(report.formattedBytesFreed)
                                    .font(.body.monospacedDigit())
                            }
                            .font(.caption)

                            // Show error details
                            if report.hasErrors {
                                ForEach(report.errors.prefix(3), id: \.path) { error in
                                    HStack(spacing: 4) {
                                        Text(URL(fileURLWithPath: error.path).lastPathComponent)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text("(in use)")
                                            .foregroundStyle(.orange)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                                }
                                if report.errors.count > 3 {
                                    Text("and \(report.errors.count - 3) more...")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 24)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 250)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 40)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Logic

    private func performCleanAll() async {
        isCleaning = true
        reports = []

        for (result, category) in effectiveResults {
            let items = result.items
            let (report, _) = await viewModel.executor.cleanAndRescan(category: category, items: items)
            reports.append(report)
            await viewModel.rescanCategory(named: result.categoryName)
        }

        isCleaning = false
        isDone = true
    }
}
