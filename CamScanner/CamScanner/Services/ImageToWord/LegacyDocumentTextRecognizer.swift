import UIKit

/// iOS 17–25: построчный OCR через VNRecognizeTextRequest. Каждая строка = отдельный параграф.
final class LegacyDocumentTextRecognizer: DocumentTextRecognizer {
    private let ocrService: OCRService

    init(ocrService: OCRService) {
        self.ocrService = ocrService
    }

    func recognizeParagraphs(in image: UIImage) async throws -> [String] {
        try await ocrService.recognizeSortedLines(in: image)
    }
}
