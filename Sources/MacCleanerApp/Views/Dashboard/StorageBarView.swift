import SwiftUI
import MacCleanerCore

struct StorageBarView: View {
    let results: [ScanResult]
    let totalDiskBytes: Int64
    let freeDiskBytes: Int64

    private let categoryColors: [Color] = [
        .red, .orange, .blue, .green, .purple, .cyan, .pink, .yellow, .mint, .indigo, .brown, .teal
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segmented bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.categoryName) { index, result in
                        let fraction = totalDiskBytes > 0
                            ? CGFloat(result.totalBytes) / CGFloat(totalDiskBytes)
                            : 0

                        if fraction > 0.005 { // Skip tiny segments
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorFor(index: index))
                                .frame(width: max(4, geo.size.width * fraction))
                                .help("\(result.categoryName): \(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))")
                        }
                    }

                    // Free space
                    let freeFraction = totalDiskBytes > 0
                        ? CGFloat(freeDiskBytes) / CGFloat(totalDiskBytes)
                        : 0
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: max(4, geo.size.width * freeFraction))
                        .help("Free: \(ByteCountFormatter.string(fromByteCount: freeDiskBytes, countStyle: .file))")
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Legend
            FlowLayout(spacing: 12) {
                ForEach(Array(results.prefix(8).enumerated()), id: \.element.categoryName) { index, result in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorFor(index: index))
                            .frame(width: 8, height: 8)
                        Text(result.categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(width: 8, height: 8)
                    Text("Free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: freeDiskBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func colorFor(index: Int) -> Color {
        categoryColors[index % categoryColors.count]
    }
}

/// Simple horizontal flow layout for legend items.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            ), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
