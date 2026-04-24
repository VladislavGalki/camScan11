import UIKit

enum ImageToWordError: LocalizedError {
    case emptyInput
    case nothingRecognized
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "No images to convert."
        case .nothingRecognized: return "No text was recognized in the images."
        case .writeFailed(let e): return "Failed to write DOCX: \(e.localizedDescription)"
        }
    }
}

protocol ImageToWordConverting {
    /// Конвертирует изображения в .docx (каждое изображение → своя страница).
    /// - Returns: URL сгенерированного файла во временной директории.
    func convert(images: [UIImage], fileName: String) async throws -> URL
}

final class ImageToWordConverter: ImageToWordConverting {
    private let writer: DOCXFileWriter
    private let legacyRecognizer: DocumentTextRecognizer
    private let modernRecognizerFactory: () -> DocumentTextRecognizer?

    init(
        ocrService: OCRService,
        writer: DOCXFileWriter = DOCXFileWriter(),
        modernRecognizerFactory: @escaping () -> DocumentTextRecognizer? = ImageToWordConverter.defaultModernFactory
    ) {
        self.writer = writer
        self.legacyRecognizer = LegacyDocumentTextRecognizer(ocrService: ocrService)
        self.modernRecognizerFactory = modernRecognizerFactory
    }

    private static func defaultModernFactory() -> DocumentTextRecognizer? {
        if #available(iOS 26.0, *) {
            return ModernDocumentTextRecognizer()
        }
        return nil
    }

    func convert(images: [UIImage], fileName: String) async throws -> URL {
        guard !images.isEmpty else { throw ImageToWordError.emptyInput }

        let recognizer: DocumentTextRecognizer = modernRecognizerFactory() ?? legacyRecognizer

        var pages: [[String]] = []
        for image in images {
            do {
                let paragraphs = try await recognizer.recognizeParagraphs(in: image)
                if !paragraphs.isEmpty {
                    pages.append(paragraphs)
                }
            } catch {
                continue
            }
        }

        guard !pages.isEmpty else { throw ImageToWordError.nothingRecognized }

        let safeName = fileName.isEmpty ? "document" : fileName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("docx")

        do {
            try writer.write(pages: pages, to: url)
        } catch {
            throw ImageToWordError.writeFailed(error)
        }
        return url
    }
}
