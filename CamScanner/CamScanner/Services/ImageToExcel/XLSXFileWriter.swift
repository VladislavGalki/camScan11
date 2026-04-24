import Foundation
import ZIPFoundation

enum XLSXWriteError: Error {
    case writeFailed
}

/// Минимальный OOXML писатель: собирает .xlsx как zip c XML-внутренностями.
/// Используем inline-строки (`<c t="inlineStr">`) — не нуждаемся в sharedStrings.xml.
final class XLSXFileWriter {
    func write(tables: [RecognizedTable], sheetNames: [String], to url: URL) throws {
        assert(tables.count == sheetNames.count)
        let fm = FileManager.default

        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }

        guard let archive = try? Archive(url: url, accessMode: .create) else {
            throw XLSXWriteError.writeFailed
        }

        try add(archive, path: "[Content_Types].xml", xml: Self.contentTypes(sheetCount: tables.count))
        try add(archive, path: "_rels/.rels", xml: Self.rootRels())
        try add(archive, path: "xl/_rels/workbook.xml.rels", xml: Self.workbookRels(sheetCount: tables.count))
        try add(archive, path: "xl/workbook.xml", xml: Self.workbook(sheetNames: sheetNames))

        for (index, table) in tables.enumerated() {
            try add(archive, path: "xl/worksheets/sheet\(index + 1).xml", xml: Self.sheet(table: table))
        }
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

    // MARK: - XML templates

    private static let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

    private static func contentTypes(sheetCount: Int) -> String {
        var overrides = ""
        for i in 1...max(sheetCount, 1) {
            overrides += #"<Override PartName="/xl/worksheets/sheet\#(i).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }
        return """
        \(header)
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        \(overrides)
        </Types>
        """
    }

    private static func rootRels() -> String {
        """
        \(header)
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private static func workbookRels(sheetCount: Int) -> String {
        var rels = ""
        for i in 1...max(sheetCount, 1) {
            rels += #"<Relationship Id="rId\#(i)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#(i).xml"/>"#
        }
        return """
        \(header)
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(rels)
        </Relationships>
        """
    }

    private static func workbook(sheetNames: [String]) -> String {
        var sheets = ""
        for (i, name) in sheetNames.enumerated() {
            let safe = escape(name.isEmpty ? "Sheet\(i + 1)" : name)
            sheets += #"<sheet name="\#(safe)" sheetId="\#(i + 1)" r:id="rId\#(i + 1)"/>"#
        }
        return """
        \(header)
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\(sheets)</sheets>
        </workbook>
        """
    }

    private static func sheet(table: RecognizedTable) -> String {
        var rowsXML = ""
        for (rowIndex, row) in table.rows.enumerated() {
            let r = rowIndex + 1
            var cells = ""
            for (colIndex, value) in row.enumerated() {
                let ref = columnLetter(colIndex) + "\(r)"
                cells += #"<c r="\#(ref)" t="inlineStr"><is><t xml:space="preserve">\#(escape(value))</t></is></c>"#
            }
            rowsXML += #"<row r="\#(r)">\#(cells)</row>"#
        }
        return """
        \(header)
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>\(rowsXML)</sheetData>
        </worksheet>
        """
    }

    private static func columnLetter(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            let rem = n % 26
            result = String(UnicodeScalar(65 + rem)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}
