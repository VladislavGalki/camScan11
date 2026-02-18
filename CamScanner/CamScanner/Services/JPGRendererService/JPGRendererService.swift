import UIKit
import AVFoundation

final class JPGRendererService {
    static let shared = JPGRendererService()

    private init() {}

    func renderJPGs(from documents: [SharePreviewModel], fileName: String, quality: CGFloat = 0.9) throws -> [URL] {
        var urls: [URL] = []

        for (index, document) in documents.enumerated() {
            guard let image = renderDocument(document) else {
                continue
            }

            guard let data = image.jpegData(compressionQuality: quality) else {
                continue
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(fileName)_\(index + 1).jpg")

            try data.write(to: url)
            urls.append(url)
        }

        return urls
    }

    // MARK: Main dispatcher

    private func renderDocument(_ document: SharePreviewModel) -> UIImage? {
        switch document.documentType {
        case .documents:
            return renderRegular(document)
        case .idCard, .driverLicense:
            return renderID(document)
        case .passport:
            return renderPassport(document)
        default:
            return nil
        }
    }

    private func renderRegular(_ document: SharePreviewModel) -> UIImage? {
        guard let image = document.frames.first?.preview else {
            return nil
        }

        let pageSize = CGSize(width: 2480, height: 3508)
        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { ctx in
            drawWhiteBackground(ctx.cgContext, pageSize)

            let rect = AVMakeRect(
                aspectRatio: image.size,
                insideRect: CGRect(origin: .zero, size: pageSize)
            )

            image.draw(in: rect)

            PDFRendererService.WatermarkRenderer.drawUIKit(
                in: ctx.cgContext,
                pageSize: pageSize
            )
        }
    }

    private func renderID(_ document: SharePreviewModel) -> UIImage? {
        let images = document.frames.compactMap(\.preview)
        
        guard !images.isEmpty else { return nil }

        let pageSize = CGSize(width: 2480, height: 3508)

        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { ctx in

            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            let imageWidth = pageSize.width * 0.6
            let aspect: CGFloat = 162.0 / 256.0
            let imageHeight = imageWidth * aspect

            let spacing: CGFloat = pageSize.height * 0.04

            let totalHeight =
                CGFloat(images.count) * imageHeight +
                CGFloat(images.count - 1) * spacing

            var y = (pageSize.height - totalHeight) / 2

            for image in images {

                let rect = CGRect(
                    x: (pageSize.width - imageWidth) / 2,
                    y: y,
                    width: imageWidth,
                    height: imageHeight
                )

                image.draw(in: rect)

                y += imageHeight + spacing
            }

            PDFRendererService.WatermarkRenderer.drawUIKit(
                in: ctx.cgContext,
                pageSize: pageSize
            )
        }
    }

    private func renderPassport(_ document: SharePreviewModel) -> UIImage? {
        guard let image = document.frames.first?.preview else {
            return nil
        }

        let pageSize = CGSize(width: 2480, height: 3508)
        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            let imageWidth = pageSize.width * 0.65
            let aspect = image.size.height / image.size.width
            let imageHeight = imageWidth * aspect

            let rect = CGRect(
                x: (pageSize.width - imageWidth)/2,
                y: (pageSize.height - imageHeight)/2,
                width: imageWidth,
                height: imageHeight
            )

            image.draw(in: rect)

            PDFRendererService.WatermarkRenderer.drawUIKit(
                in: ctx.cgContext,
                pageSize: pageSize
            )
        }
    }
    
    private func drawWhiteBackground(
        _ ctx: CGContext,
        _ size: CGSize
    ) {
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}
