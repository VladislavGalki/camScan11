import UIKit

final class ShareExportService {
    static let shared = ShareExportService()

    private init() {}

    func exportPDF(
        documents: [SharePreviewModel],
        split: Bool,
        zip: Bool,
        password: String?,
        addWatermark: Bool,
        fileName: String
    ) throws -> [URL] {
        let renderer = PDFRendererService()
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
            let zipURL = try ZipService.shared.zip(files: urls, fileName: fileName)
            return [zipURL]
        }

        return urls
    }
    
    func exportJPG(documents: [SharePreviewModel], zip: Bool, fileName: String) throws -> [URL] {
        let renderer = JPGRendererService.shared
        
        do {
            let urls = try renderer.renderJPGs(from: documents, fileName: fileName)
            
            if zip {
                let zipURL = try ZipService.shared.zip(files: urls, fileName: fileName)
                return [zipURL]
            }
            
            return urls
        } catch {
            return []
        }
    }
}
