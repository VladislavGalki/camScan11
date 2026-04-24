import UIKit
import Vision

/// iOS 26+: RecognizeDocumentsRequest сам группирует строки в параграфы.
/// Каждый `document.paragraphs[]` → один <w:p> в docx.
@available(iOS 26.0, *)
final class ModernDocumentTextRecognizer: DocumentTextRecognizer {
    func recognizeParagraphs(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage ?? image.normalizedUp().cgImage else {
            return []
        }

        let request = RecognizeDocumentsRequest()
        let observations = try await request.perform(on: cgImage)

        // Сортируем параграфы top→bottom по Y (Vision: Y от нижнего угла → 1 - midY).
        var paragraphs: [(text: String, y: CGFloat)] = []
        for obs in observations {
            for paragraph in obs.document.paragraphs {
                let text = paragraph.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let bb = paragraph.boundingRegion.boundingBox
                paragraphs.append((text, 1.0 - (bb.origin.y + bb.height / 2)))
            }
        }

        return paragraphs.sorted { $0.y < $1.y }.map(\.text)
    }
}
