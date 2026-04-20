import UIKit

enum ShareExportError: LocalizedError {
    case emptyOCRResult

    var errorDescription: String? {
        switch self {
        case .emptyOCRResult:
            return "No text was recognized in the selected documents."
        }
    }
}

final class ShareExportService {
    private let ocrService: OCRService
    private let zipService: ZipService
    private let jpgRenderer: JPGRendererService
    private let pdfRendererFactory: () -> PDFRendererService

    init(
        ocrService: OCRService,
        zipService: ZipService,
        jpgRenderer: JPGRendererService,
        pdfRendererFactory: @escaping () -> PDFRendererService
    ) {
        self.ocrService = ocrService
        self.zipService = zipService
        self.jpgRenderer = jpgRenderer
        self.pdfRendererFactory = pdfRendererFactory
    }

    func exportPDF(
        documents: [SharePreviewModel],
        split: Bool,
        zip: Bool,
        password: String?,
        addWatermark: Bool,
        fileName: String
    ) throws -> [URL] {
        let renderer = pdfRendererFactory()
        var urls: [URL] = []
        
        if split {
            for (index, doc) in documents.enumerated() {
                let url = try renderer.renderSingle(
                    document: doc,
                    fileName: "\(fileName)_\(index + 1)",
                    password: password,
                    addWatermark: addWatermark
                )

                urls.append(url)
            }
        } else {
            let url = try renderer.renderCombined(
                documents: documents,
                fileName: fileName,
                password: password,
                addWatermark: addWatermark
            )

            urls.append(url)
        }

        if zip {
            let zipURL = try zipService.zip(files: urls, fileName: fileName)
            return [zipURL]
        }

        return urls
    }
    
    func exportTXT(documents: [SharePreviewModel], zip: Bool, fileName: String) async throws -> [URL] {
        var allTexts: [String] = []

        for document in documents {
            for frame in document.frames {
                guard let image = frame.preview else { continue }
                let result = try await ocrService.recognizeText(in: image)
                let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    allTexts.append(trimmed)
                }
            }
        }

        guard !allTexts.isEmpty else {
            throw ShareExportError.emptyOCRResult
        }

        let combinedText = allTexts.joined(separator: "\n\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).txt")

        try combinedText.write(to: url, atomically: true, encoding: .utf8)

        if zip {
            let zipURL = try zipService.zip(files: [url], fileName: fileName)
            return [zipURL]
        }

        return [url]
    }

    func exportJPG(documents: [SharePreviewModel], zip: Bool, fileName: String) throws -> [URL] {
        let renderer = jpgRenderer
        
        do {
            let urls = try renderer.renderJPGs(from: documents, fileName: fileName)
            
            if zip {
                let zipURL = try zipService.zip(files: urls, fileName: fileName)
                return [zipURL]
            }
            
            return urls
        } catch {
            return []
        }
    }
}
