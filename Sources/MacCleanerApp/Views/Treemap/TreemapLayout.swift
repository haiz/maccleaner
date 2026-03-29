import Foundation

/// Squarified treemap layout algorithm.
/// Reference: Bruls, Huizing, van Wijk — "Squarified Treemaps" (2000).
struct TreemapLayout {

    struct Cell {
        let index: Int
        let label: String
        let value: Double
        let rect: CGRect
    }

    /// Compute treemap cell rects for given data within a bounding rect.
    static func layout(
        data: [(label: String, value: Double)],
        in rect: CGRect
    ) -> [Cell] {
        guard !data.isEmpty else { return [] }

        let total = data.reduce(0.0) { $0 + $1.value }
        guard total > 0 else { return [] }

        // Normalize values to fit the area
        let area = Double(rect.width * rect.height)
        var items = data.enumerated().map { (index: $0.offset, label: $0.element.label, value: $0.element.value / total * area) }
        items.sort { $0.value > $1.value }

        var cells: [Cell] = []
        var remaining = CGRect(
            x: Double(rect.minX),
            y: Double(rect.minY),
            width: Double(rect.width),
            height: Double(rect.height)
        )
        var i = 0

        while i < items.count {
            let shortSide = min(remaining.width, remaining.height)
            guard shortSide > 0 else { break }

            // Find the optimal row
            var row: [(index: Int, label: String, value: Double)] = []
            var rowSum: Double = 0

            let bestRatio = { (items: [(index: Int, label: String, value: Double)], total: Double, side: Double) -> Double in
                guard side > 0 && total > 0 else { return .infinity }
                var worst: Double = 0
                for item in items {
                    let ratio = max(
                        (side * side * item.value) / (total * total),
                        (total * total) / (side * side * item.value)
                    )
                    worst = max(worst, ratio)
                }
                return worst
            }

            row.append(items[i])
            rowSum = items[i].value
            var currentRatio = bestRatio(row, rowSum, Double(shortSide))
            i += 1

            while i < items.count {
                var testRow = row
                testRow.append(items[i])
                let testSum = rowSum + items[i].value
                let testRatio = bestRatio(testRow, testSum, Double(shortSide))

                if testRatio <= currentRatio {
                    row.append(items[i])
                    rowSum = testSum
                    currentRatio = testRatio
                    i += 1
                } else {
                    break
                }
            }

            // Layout this row
            let isHorizontal = remaining.width >= remaining.height
            let rowLength = rowSum / Double(shortSide)

            var offset: Double = 0
            for item in row {
                let itemLength = item.value / rowSum * Double(shortSide)

                let cellRect: CGRect
                if isHorizontal {
                    cellRect = CGRect(
                        x: remaining.minX,
                        y: remaining.minY + offset,
                        width: rowLength,
                        height: itemLength
                    )
                } else {
                    cellRect = CGRect(
                        x: remaining.minX + offset,
                        y: remaining.minY,
                        width: itemLength,
                        height: rowLength
                    )
                }

                cells.append(Cell(
                    index: item.index,
                    label: item.label,
                    value: item.value,
                    rect: cellRect
                ))
                offset += itemLength
            }

            // Shrink remaining rect
            if isHorizontal {
                remaining = CGRect(
                    x: remaining.minX + rowLength,
                    y: remaining.minY,
                    width: remaining.width - rowLength,
                    height: remaining.height
                )
            } else {
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + rowLength,
                    width: remaining.width,
                    height: remaining.height - rowLength
                )
            }
        }

        return cells
    }
}
