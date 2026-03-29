import SwiftUI
import MacCleanerCore

struct TreemapView: View {
    let results: [ScanResult]
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var cells: [TreemapLayout.Cell] = []
    @State private var hoveredIndex: Int? = nil

    private let categoryColors: [Color] = [
        .red, .orange, .blue, .green, .purple, .cyan, .pink, .yellow, .mint, .indigo, .brown, .teal
    ]

    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage Breakdown")
                .font(.headline)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let size = geo.size
                let computedCells = TreemapLayout.layout(
                    data: results.map { ($0.categoryName, Double($0.totalBytes)) },
                    in: CGRect(origin: .zero, size: size)
                )

                ZStack(alignment: .topLeading) {
                    // Render cells
                    ForEach(computedCells, id: \.index) { cell in
                        let color = categoryColors[cell.index % categoryColors.count]
                        let isHovered = hoveredIndex == cell.index
                        let insetRect = cell.rect.insetBy(dx: gap / 2, dy: gap / 2)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.gradient)
                            .opacity(isHovered ? 0.85 : 1.0)
                            .frame(width: max(0, insetRect.width), height: max(0, insetRect.height))
                            .overlay(alignment: .topLeading) {
                                cellLabel(for: cell, in: insetRect)
                            }
                            .position(x: insetRect.midX, y: insetRect.midY)
                            .onHover { isHovered in
                                hoveredIndex = isHovered ? cell.index : nil
                            }
                            .onTapGesture {
                                viewModel.selectedSidebarItem = .category(results[cell.index].categoryName)
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func cellLabel(for cell: TreemapLayout.Cell, in rect: CGRect) -> some View {
        if rect.width > 60 && rect.height > 40 {
            VStack(alignment: .leading, spacing: 2) {
                Text(cell.label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if rect.height > 55 {
                    let result = results[cell.index]
                    Text(ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file))
                        .font(.system(size: rect.width > 100 ? 16 : 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(8)
        }
    }
}
