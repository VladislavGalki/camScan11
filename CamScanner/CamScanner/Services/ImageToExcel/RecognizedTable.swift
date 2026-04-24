import Foundation

struct RecognizedTable: Equatable {
    var rows: [[String]]

    var isEmpty: Bool {
        rows.allSatisfy { $0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func padded(_ rows: [[String]]) -> RecognizedTable {
        let width = rows.map(\.count).max() ?? 0
        let normalized = rows.map { row -> [String] in
            row + Array(repeating: "", count: max(0, width - row.count))
        }
        return RecognizedTable(rows: normalized)
    }
}
