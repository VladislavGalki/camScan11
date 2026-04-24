import CoreGraphics

/// Вход для алгоритма группировки: текст + нормализованный bbox в координатах
/// с осью Y сверху вниз (0 — верх изображения, 1 — низ).
struct TableTextItem {
    let text: String
    let minX: CGFloat
    let midX: CGFloat
    let midY: CGFloat
}

enum TableGrouping {
    static func buildTable(
        from items: [TableTextItem],
        rowTolerance: CGFloat = 0.022,
        colTolerance: CGFloat = 0.03
    ) -> [[String]] {
        let rows = groupIntoRows(items, tolerance: rowTolerance)
        let columnCenters = inferColumnCenters(from: rows, tolerance: colTolerance)
        return placeItems(rows: rows, columnCenters: columnCenters)
    }

    /// Группируем по Y относительно СРЕДНЕГО midY текущей строки — это убирает дрейф,
    /// возникающий при сравнении только с первым элементом кластера.
    static func groupIntoRows(_ items: [TableTextItem], tolerance: CGFloat) -> [[TableTextItem]] {
        let sorted = items.sorted { $0.midY < $1.midY }
        var rows: [[TableTextItem]] = []
        var rowMeans: [CGFloat] = []

        for item in sorted {
            if let lastMean = rowMeans.last,
               abs(item.midY - lastMean) <= tolerance {
                let lastIndex = rows.count - 1
                rows[lastIndex].append(item)
                let n = CGFloat(rows[lastIndex].count)
                rowMeans[lastIndex] = (lastMean * (n - 1) + item.midY) / n
            } else {
                rows.append([item])
                rowMeans.append(item.midY)
            }
        }

        return rows.map { $0.sorted { $0.minX < $1.minX } }
    }

    static func inferColumnCenters(from rows: [[TableTextItem]], tolerance: CGFloat) -> [CGFloat] {
        let xs = rows.flatMap { $0.map(\.midX) }.sorted()
        guard !xs.isEmpty else { return [] }

        var clusters: [[CGFloat]] = [[xs[0]]]
        for x in xs.dropFirst() {
            let lastCluster = clusters[clusters.count - 1]
            let clusterMean = lastCluster.reduce(0, +) / CGFloat(lastCluster.count)
            if abs(x - clusterMean) <= tolerance {
                clusters[clusters.count - 1].append(x)
            } else {
                clusters.append([x])
            }
        }
        return clusters.map { $0.reduce(0, +) / CGFloat($0.count) }
    }

    static func placeItems(rows: [[TableTextItem]], columnCenters: [CGFloat]) -> [[String]] {
        guard !columnCenters.isEmpty else {
            return rows.map { $0.map(\.text) }
        }
        return rows.map { row -> [String] in
            var cells = Array(repeating: "", count: columnCenters.count)
            for item in row {
                let idx = nearestIndex(item.midX, in: columnCenters)
                cells[idx] = cells[idx].isEmpty ? item.text : cells[idx] + " " + item.text
            }
            return cells
        }
    }

    private static func nearestIndex(_ value: CGFloat, in centers: [CGFloat]) -> Int {
        var best = 0
        var bestDist = CGFloat.infinity
        for (i, c) in centers.enumerated() {
            let d = abs(value - c)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }
}
