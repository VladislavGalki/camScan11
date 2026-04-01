import UIKit
import CoreGraphics

enum PDFImageExtractor {
    static func extractImages(from url: URL) -> [UIImage] {
        guard let document = CGPDFDocument(url as CFURL) else { return [] }

        var images: [UIImage] = []

        for pageIndex in 1...document.numberOfPages {
            guard let page = document.page(at: pageIndex) else { continue }

            let mediaBox = page.getBoxRect(.mediaBox)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: mediaBox.size, format: format)

            let image = renderer.image { context in
                let cgContext = context.cgContext
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: mediaBox.size))

                cgContext.translateBy(x: 0, y: mediaBox.size.height)
                cgContext.scaleBy(x: 1, y: -1)
                cgContext.drawPDFPage(page)
            }

            images.append(image)
        }

        return images
    }
}
