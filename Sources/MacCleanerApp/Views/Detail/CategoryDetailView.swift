import SwiftUI
import MacCleanerCore

struct CategoryDetailView: View {
    let categoryName: String
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var isCleaning = false
    @State private var showCleanConfirm = false
    @State private var cleanupReport: CleanupReport?

    private var result: ScanResult? {
        viewModel.results.first { $0.categoryName == categoryName }
            ?? viewModel.nonEmptyResults.first { $0.categoryName == categoryName }
    }

    private var cleanableCategory: (any CleanableCategory)? {
        viewModel.executor.findCleanableCategory(named: categoryName)
    }

    private var isSafe: Bool {
        result?.safetyLevel == .safe
    }

    var body: some View {
        VStack(spacing: 0) {
            if let result {
                headerView(result)
                Divider()

                if result.items.isEmpty {
                    emptyStateView
                } else {
                    // Read-only file list (no selection, no multi-select)
                    fileListView(result)
                }

                // Action bar: different for Safe vs Caution
                if !result.items.isEmpty {
                    actionBarView(result)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Category Not Found")
                        .font(.title3)
                    Text("Scan to discover this category.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Clean \(categoryName)", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean All", role: .destructive) {
                Task { await performCleanup() }
            }
        } message: {
            if let result {
                let sizeStr = ByteCountFormatter.string(fromByteCount: result.effectiveReclaimableBytes, countStyle: .file)
                let method = cleanableCategory?.isIrreversible == true
                    ? "This action cannot be undone."
                    : "Items will be moved to Trash. You can recover them from Trash if needed."
                Text("Clean all \(result.items.count) items in \(categoryName)?\n\n\(sizeStr) will be freed.\n\n\(method)")
            }
        }
        .sheet(item: $cleanupReport) { report in
            CleanupReportView(report: report)
        }
    }

    // MARK: - Header

    private func headerView(_ result: ScanResult) -> some View {
        HStack {
            Image(systemName: result.categoryIcon)
                .font(.title)
                .foregroundStyle(isSafe ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.categoryName)
                    .font(.title2.bold())

                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))
                        .font(.headline)
                        .foregroundStyle(.red)

                    if let reclaimable = result.reclaimableBytes {
                        Text("(\(ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .file)) reclaimable)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let error = result.error {
                        Label(error.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Safety badge
            if isSafe {
                Label("Safe to clean", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Label("Review before cleaning", systemImage: "exclamationmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(16)
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No Items")
                .font(.title3)
            Text("This category is empty or not accessible.")
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Read-only file list (NO selection)

    private func fileListView(_ result: ScanResult) -> some View {
        let sortedItems = result.items.sorted { $0.sizeBytes > $1.sizeBytes }
        return List {
            ForEach(sortedItems) { item in
                FileRowView(item: item)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Action bar

    private func actionBarView(_ result: ScanResult) -> some View {
        HStack {
            let sizeStr = ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file)

            Text("\(result.items.count) items")
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(sizeStr)
                .bold()
                .foregroundStyle(.red)

            Spacer()

            // Reveal in Finder (always available)
            if let firstItem = result.items.first {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(firstItem.path, inFileViewerRootedAtPath: "")
                }
                .controlSize(.regular)
            }

            // Clean button: only for Safe + CleanableCategory
            if let _ = cleanableCategory, isSafe {
                Button(isCleaning ? "Cleaning..." : "Clean All") {
                    showCleanConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isCleaning)
            }

            // Caution categories: no clean button, only info
            if result.safetyLevel == .caution && cleanableCategory != nil {
                Text("Use Clean All (3-tier) for safe cleanup")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Logic

    private func performCleanup() async {
        guard let result, let category = cleanableCategory else { return }

        isCleaning = true
        let (report, _) = await viewModel.executor.cleanAndRescan(category: category, items: result.items)

        await viewModel.rescanCategory(named: categoryName)
        isCleaning = false
        cleanupReport = report
    }
}

// MARK: - File Row (read-only, no selection state)

struct FileRowView: View {
    let item: CleanableItem
    @State private var showInfo = false

    private var dirInfo: String? {
        DirectoryInfo.description(for: item.path)
            ?? DirectoryInfo.description(for: URL(fileURLWithPath: item.path).lastPathComponent)
            ?? (item.description.count > 20 ? item.description : nil)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(URL(fileURLWithPath: item.path).lastPathComponent)
                        .font(.body)

                    if dirInfo != nil {
                        Button(action: { showInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                                    .font(.headline)
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Divider()
                                Text(dirInfo ?? "")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(width: 350)
                        }
                    }
                }

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Per-item Reveal in Finder
            Button(action: {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            if let lastAccessed = item.lastAccessed {
                Text(lastAccessed, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.formattedSize)
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(item.sizeBytes > 1_000_000_000 ? .red : .primary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(action: {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Cleanup Report Sheet

struct CleanupReportView: View {
    let report: CleanupReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            if report.hasErrors {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            }

            Text(report.hasErrors ? "Cleanup Completed with Errors" : "Cleanup Complete!")
                .font(.title2.bold())

            Text("\(report.formattedBytesFreed) freed")
                .font(.title3)
                .foregroundStyle(.secondary)

            if report.hasErrors {
                Text("Items were moved to Trash. You can recover them if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Items moved to Trash. Open Trash to recover if needed.")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if !report.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .font(.caption.bold())
                    ForEach(report.errors, id: \.path) { error in
                        Text("\(error.path): \(error.message)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 400)
    }
}

extension CleanupReport: Identifiable {
    public var id: String { categoryName }
}
