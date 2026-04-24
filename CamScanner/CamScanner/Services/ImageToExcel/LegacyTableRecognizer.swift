import UIKit
import Vision

final class LegacyTableRecognizer: TableRecognizer {
    private let rowTolerance: CGFloat
    private let colTolerance: CGFloat
    private let languages: [String]

    init(
        rowTolerance: CGFloat = 0.022,
        colTolerance: CGFloat = 0.03,
        languages: [String] = ocrLanguages
    ) {
        self.rowTolerance = rowTolerance
        self.colTolerance = colTolerance
        self.languages = languages
    }

    func recognizeTable(in image: UIImage) async throws -> RecognizedTable {
        guard let cgImage = image.cgImage ?? image.normalizedUp().cgImage else {
            throw TableRecognizerError.emptyImage
        }

        let observations = try await performRequest(on: cgImage)
        let items = observations.compactMap(Self.makeItem)
        guard !items.isEmpty else { throw TableRecognizerError.noText }

        let matrix = TableGrouping.buildTable(
            from: items,
            rowTolerance: rowTolerance,
            colTolerance: colTolerance
        )
        return RecognizedTable.padded(matrix)
    }

    private func performRequest(on cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: TableRecognizerError.visionFailure(err))
                    return
                }
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                cont.resume(returning: obs)
            }
            request.recognitionLanguages = languages
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(throwing: TableRecognizerError.visionFailure(error)) }
            }
        }
    }

    private static func makeItem(from obs: VNRecognizedTextObservation) -> TableTextItem? {
        guard let text = obs.topCandidates(1).first?.string else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let bb = obs.boundingBox
        // Vision boundingBox: нормализован [0,1], Y от НИЖНЕГО левого угла.
        // Инвертируем в «экранную» систему (0 сверху), чтобы группировка шла top→bottom.
        return TableTextItem(
            text: trimmed,
            minX: bb.minX,
            midX: bb.midX,
            midY: 1.0 - bb.midY
        )
    }
}
