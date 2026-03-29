import SwiftUI
import MacCleanerCore

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var showCleanAll = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header + Clean All button
                HStack(alignment: .top) {
                    headerSection
                    Spacer()
                    if viewModel.hasScanned && viewModel.totalReclaimableBytes > 0 {
                        Button(action: { showCleanAll = true }) {
                            Label("Clean All", systemImage: "sparkles")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                }

                if viewModel.isScanning {
                    scanningSection
                }

                if !viewModel.nonEmptyResults.isEmpty {
                    // APFS volume breakdown
                    if !viewModel.apfsVolumes.isEmpty {
                        APFSBreakdownView(
                            volumes: viewModel.apfsVolumes,
                            containerTotal: viewModel.totalDiskBytes,
                            containerFree: viewModel.freeDiskBytes
                        )
                    }

                    // Storage bar
                    StorageBarView(
                        results: viewModel.nonEmptyResults,
                        totalDiskBytes: viewModel.totalDiskBytes,
                        freeDiskBytes: viewModel.freeDiskBytes
                    )

                    // Treemap
                    TreemapView(results: viewModel.nonEmptyResults)
                        .frame(height: 280)

                    // Category cards
                    CategoryCardsView()
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showCleanAll) {
            CleanAllView()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Macintosh HD")
                .font(.title.bold())

            HStack(spacing: 8) {
                let totalStr = ByteCountFormatter.string(
                    fromByteCount: viewModel.totalDiskBytes, countStyle: .file)
                let freeStr = ByteCountFormatter.string(
                    fromByteCount: viewModel.freeDiskBytes, countStyle: .file)

                Text("\(totalStr) total")
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(freeStr) free")
                    .foregroundStyle(viewModel.freeDiskBytes < 20_000_000_000 ? .red : .secondary)

                if viewModel.hasScanned {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    let reclaimStr = ByteCountFormatter.string(
                        fromByteCount: viewModel.totalReclaimableBytes, countStyle: .file)
                    Text("\(reclaimStr) reclaimable")
                        .foregroundStyle(.green)
                }
            }
            .font(.subheadline)
        }
    }

    private var scanningSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(viewModel.scanProgress)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
}
