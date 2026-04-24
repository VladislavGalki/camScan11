import UIKit
import Vision

/// iOS 26+: RecognizeDocumentsRequest — сам детектит таблицы.
/// Если таблиц нет — собираем строки документа через кластеризацию по bbox как в legacy-пути.
@available(iOS 26.0, *)
final class ModernTableRecognizer: TableRecognizer {
    private let rowTolerance: CGFloat
    private let colTolerance: CGFloat

    init(rowTolerance: CGFloat = 0.022, colTolerance: CGFloat = 0.03) {
        self.rowTolerance = rowTolerance
        self.colTolerance = colTolerance
    }

    func recognizeTable(in image: UIImage) async throws -> RecognizedTable {
        guard let cgImage = image.cgImage ?? image.normalizedUp().cgImage else {
            throw TableRecognizerError.emptyImage
        }

        do {
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: cgImage)

            if let matrix = Self.extractTable(from: observations), !matrix.isEmpty {
                return RecognizedTable.padded(matrix)
            }

            let items = Self.extractLineItems(from: observations)
            guard !items.isEmpty else { throw TableRecognizerError.noText }

            let matrix = TableGrouping.buildTable(
                from: items,
                rowTolerance: rowTolerance,
                colTolerance: colTolerance
            )
            return RecognizedTable.padded(matrix)
        } catch let err as TableRecognizerError {
            throw err
        } catch {
            throw TableRecognizerError.visionFailure(error)
        }
    }

    private static func extractTable(from observations: [DocumentObservation]) -> [[String]]? {
        for observation in observations {
            for table in observation.document.tables {
                let rows: [[String]] = table.rows.map { row in
                    row.map { cell in
                        cell.content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                if !rows.isEmpty { return rows }
            }
        }
        return nil
    }

    private static func extractLineItems(from observations: [DocumentObservation]) -> [TableTextItem] {
        var items: [TableTextItem] = []
        for obs in observations {
            for paragraph in obs.document.paragraphs {
                for line in paragraph.lines {
                    let text = line.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    let bb = line.boundingRegion.boundingBox
                    // Vision нормализует bbox от нижнего левого угла — инвертируем в top→bottom.
                    let midYBottomOrigin = bb.origin.y + bb.height / 2
                    items.append(TableTextItem(
                        text: text,
                        minX: bb.origin.x,
                        midX: bb.origin.x + bb.width / 2,
                        midY: 1.0 - midYBottomOrigin
                    ))
                }
            }
        }
        return items
    }
}
