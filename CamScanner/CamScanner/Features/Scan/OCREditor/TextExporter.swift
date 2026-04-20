import Foundation

final class TextExporter {
    init() {}

    enum ExportError: Error {
        case emptyText
        case failedToWrite
    }

    func exportTXT(text: String, fileName: String) throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExportError.emptyText }

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = fileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let url = tempDir.appendingPathComponent("\(safeName).txt")

        do {
            try trimmed.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.failedToWrite
        }

        return url
    }
}
