import Foundation
import ZIPFoundation

enum DOCXWriteError: Error {
    case writeFailed
}

/// Минимальный OOXML .docx-писатель: zip с тремя XML-файлами.
/// На входе — массив страниц; каждая страница = массив параграфов.
/// Между страницами вставляется разрыв страницы.
final class DOCXFileWriter {
    func write(pages: [[String]], to url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }

        guard let archive = try? Archive(url: url, accessMode: .create) else {
            throw DOCXWriteError.writeFailed
        }

        try add(archive, path: "[Content_Types].xml", xml: Self.contentTypes())
        try add(archive, path: "_rels/.rels", xml: Self.rootRels())
        try add(archive, path: "word/document.xml", xml: Self.document(pages: pages))
    }

    private func add(_ archive: Archive, path: String, xml: String) throws {
        let data = Data(xml.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate,
            provider: { position, size -> Data in
                let start = Int(position)
                let end = min(start + size, data.count)
                guard start < end else { return Data() }
                return data.subdata(in: start..<end)
            }
        )
    }

    // MARK: - XML

    private static let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

    private static func contentTypes() -> String {
        """
        \(header)
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
    }

    private static func rootRels() -> String {
        """
        \(header)
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
    }

    private static func document(pages: [[String]]) -> String {
        var body = ""
        for (pageIndex, paragraphs) in pages.enumerated() {
            for (paraIndex, text) in paragraphs.enumerated() {
                let isLastOfPage = paraIndex == paragraphs.count - 1
                let isLastPage = pageIndex == pages.count - 1
                let pageBreak = (isLastOfPage && !isLastPage)
                    ? #"<w:r><w:br w:type="page"/></w:r>"#
                    : ""
                body += #"<w:p><w:r><w:t xml:space="preserve">\#(escape(text))</w:t></w:r>\#(pageBreak)</w:p>"#
            }
            if paragraphs.isEmpty && pageIndex != pages.count - 1 {
                body += #"<w:p><w:r><w:br w:type="page"/></w:r></w:p>"#
            }
        }

        return """
        \(header)
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>\(body)<w:sectPr/></w:body>
        </w:document>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}
