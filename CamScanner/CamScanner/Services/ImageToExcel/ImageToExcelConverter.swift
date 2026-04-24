import UIKit

enum ImageToExcelError: LocalizedError {
    case emptyInput
    case nothingRecognized
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "No images to convert."
        case .nothingRecognized: return "No text or tables were recognized in the images."
        case .writeFailed(let e): return "Failed to write XLSX: \(e.localizedDescription)"
        }
    }
}

protocol ImageToExcelConverting {
    /// Конвертирует набор изображений в единый .xlsx (по одному листу на изображение).
    /// - Returns: URL сгенерированного файла во временной директории.
    func convert(images: [UIImage], fileName: String) async throws -> URL
}

final class ImageToExcelConverter: ImageToExcelConverting {
    private let writer: XLSXFileWriter
    private let legacyRecognizer: TableRecognizer
    private let modernRecognizerFactory: () -> TableRecognizer?

    init(
        writer: XLSXFileWriter = XLSXFileWriter(),
        legacyRecognizer: TableRecognizer = LegacyTableRecognizer(),
        modernRecognizerFactory: @escaping () -> TableRecognizer? = ImageToExcelConverter.defaultModernFactory
    ) {
        self.writer = writer
        self.legacyRecognizer = legacyRecognizer
        self.modernRecognizerFactory = modernRecognizerFactory
    }

    private static func defaultModernFactory() -> TableRecognizer? {
        if #available(iOS 26.0, *) {
            return ModernTableRecognizer()
        }
        return nil
    }

    func convert(images: [UIImage], fileName: String) async throws -> URL {
        guard !images.isEmpty else { throw ImageToExcelError.emptyInput }

        let recognizer: TableRecognizer = modernRecognizerFactory() ?? legacyRecognizer

        var tables: [RecognizedTable] = []
        var sheetNames: [String] = []

        for (index, image) in images.enumerated() {
            do {
                let table = try await recognizer.recognizeTable(in: image)
                if !table.isEmpty {
                    tables.append(table)
                    sheetNames.append("Sheet\(index + 1)")
                }
            } catch TableRecognizerError.noText, TableRecognizerError.emptyImage {
                continue
            }
        }

        guard !tables.isEmpty else { throw ImageToExcelError.nothingRecognized }

        let safeName = fileName.isEmpty ? "document" : fileName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("xlsx")

        do {
            try writer.write(tables: tables, sheetNames: sheetNames, to: url)
        } catch {
            throw ImageToExcelError.writeFailed(error)
        }
        return url
    }
}
