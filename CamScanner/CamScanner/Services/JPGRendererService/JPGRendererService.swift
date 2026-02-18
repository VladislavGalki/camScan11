import UIKit
import AVFoundation

final class JPGRendererService {

    static let shared = JPGRendererService()

    private init() {}

    private let pageSize = CGSize(width: 1240, height: 1754)

    func renderJPGs(from documents: [SharePreviewModel], fileName: String, quality: CGFloat = 0.82
    ) throws -> [URL] {
        var urls: [URL] = []

        for (index, document) in documents.enumerated() {
            guard let image = renderDocument(document) else {
                continue
            }

            guard let data = image.jpegData(
                compressionQuality: quality
            ) else {
                continue
            }

            let url =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "\(fileName)_\(index + 1).jpg"
                )

            try data.write(to: url)
            urls.append(url)
        }

        return urls
    }

    // MARK: Dispatcher

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

    // MARK: Documents

    private func renderRegular(_ document: SharePreviewModel) -> UIImage? {
        guard let original =
            document.frames.first?.preview
        else {
            return nil
        }

        let compressed =
            ImageCompressionService.shared.compress(
                original,
                maxDimension: 1920,
                quality: 0.75
            )

        let renderer =
            UIGraphicsImageRenderer(
                size: pageSize
            )

        return renderer.image { ctx in
            drawWhiteBackground(
                ctx.cgContext,
                pageSize
            )

            let rect =
                AVMakeRect(
                    aspectRatio: compressed.size,
                    insideRect: CGRect(
                        origin: .zero,
                        size: pageSize
                    )
                )

            compressed.draw(in: rect)

            PDFRendererService.WatermarkRenderer
                .drawUIKit(
                    in: ctx.cgContext,
                    pageSize: pageSize
                )
        }
    }

    private func renderID(_ document: SharePreviewModel) -> UIImage? {
        let originals =
            document.frames.compactMap(\.preview)

        guard !originals.isEmpty else {
            return nil
        }

        let images =
            originals.map {
                ImageCompressionService.shared.compress(
                    $0,
                    maxDimension: 1240,
                    quality: 0.75
                )
            }

        let renderer =
            UIGraphicsImageRenderer(
                size: pageSize
            )

        return renderer.image { ctx in
            drawWhiteBackground(
                ctx.cgContext,
                pageSize
            )

            let imageWidth =
                pageSize.width * 0.75

            let aspect: CGFloat =
                162.0 / 256.0

            let imageHeight =
                imageWidth * aspect

            let spacing =
                pageSize.height * 0.04

            let totalHeight =
                CGFloat(images.count)
                * imageHeight +
                CGFloat(images.count - 1)
                * spacing

            var y =
                (pageSize.height - totalHeight)
                / 2

            for image in images {

                let rect = CGRect(
                    x:
                        (pageSize.width - imageWidth)
                        / 2,
                    y: y,
                    width: imageWidth,
                    height: imageHeight
                )

                image.draw(in: rect)

                y += imageHeight + spacing
            }

            PDFRendererService.WatermarkRenderer
                .drawUIKit(
                    in: ctx.cgContext,
                    pageSize: pageSize
                )
        }
    }

    private func renderPassport(_ document: SharePreviewModel) -> UIImage? {
        guard let original =
            document.frames.first?.preview
        else {
            return nil
        }

        let image =
            ImageCompressionService.shared.compress(
                original,
                maxDimension: 1600,
                quality: 0.75
            )

        let renderer =
            UIGraphicsImageRenderer(
                size: pageSize
            )

        return renderer.image { ctx in

            drawWhiteBackground(
                ctx.cgContext,
                pageSize
            )

            let imageWidth =
                pageSize.width * 0.8

            let aspect =
                image.size.height /
                image.size.width

            let imageHeight =
                imageWidth * aspect

            let rect = CGRect(
                x:
                    (pageSize.width - imageWidth)
                    / 2,
                y:
                    (pageSize.height - imageHeight)
                    / 2,
                width: imageWidth,
                height: imageHeight
            )

            image.draw(in: rect)

            PDFRendererService.WatermarkRenderer
                .drawUIKit(
                    in: ctx.cgContext,
                    pageSize: pageSize
                )
        }
    }

    // MARK: Background

    private func drawWhiteBackground(_ ctx: CGContext,_ size: CGSize) {
        ctx.setFillColor(
            UIColor.white.cgColor
        )

        ctx.fill(
            CGRect(
                origin: .zero,
                size: size
            )
        )
    }
}
