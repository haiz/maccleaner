import SwiftUI
import MacCleanerCore

struct CategoryCardsView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    /// Only categories that have actual cleanup actions.
    private var actionableResults: [ScanResult] {
        viewModel.nonEmptyResults.filter { result in
            viewModel.executor.findCleanableCategory(named: result.categoryName) != nil
        }
    }

    var body: some View {
        if !actionableResults.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(actionableResults.prefix(8), id: \.categoryName) { result in
                        CategoryCardView(result: result)
                    }
                }
            }
        }
    }
}

struct CategoryCardView: View {
    let result: ScanResult
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var isCleaning = false

    private var isCleanable: Bool {
        viewModel.executor.findCleanableCategory(named: result.categoryName) != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.categoryIcon)
                .font(.title2)
                .foregroundStyle(result.safetyLevel == .safe ? .green : .orange)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(result.safetyLevel == .safe
                            ? Color.green.opacity(0.1)
                            : Color.orange.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(result.categoryName)
                    .font(.subheadline.bold())

                if let error = result.error {
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if let reclaimable = result.reclaimableBytes {
                    Text("\(ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .file)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isCleanable && result.safetyLevel == .safe {
                    Text("Safe to clean")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isCleanable {
                    Text("Review before cleaning")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("View only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))
                .font(.title3.bold())
                .foregroundStyle(result.totalBytes > 1_000_000_000 ? .red : .primary)

            if isCleanable {
                Button(action: {
                    viewModel.selectedSidebarItem = .category(result.categoryName)
                }) {
                    Text(result.safetyLevel == .safe ? "Clean" : "Review")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(result.safetyLevel == .safe ? .green : .orange)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}
