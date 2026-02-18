import UIKit
import CoreGraphics
import ZIPFoundation

final class PDFRendererService {
    private let pageMargin: CGFloat = 32
    
    private let pageSize = CGSize(
        width: 595,
        height: 842
    ) // А4
    
    
    func renderCombined(documents: [SharePreviewModel], fileName: String, password: String?, addWatermark: Bool) throws -> URL {
        let url = tempURL(fileName: fileName)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: pdfFormat(password: password)
        )

        try renderer.writePDF(to: url) { ctx in
            for doc in documents {
                ctx.beginPage()

                drawDocument(
                    doc,
                    in: ctx.cgContext,
                    addWatermark: addWatermark
                )
            }
        }

        return url
    }
    
    func renderSingle(document: SharePreviewModel, fileName: String, password: String?, addWatermark: Bool) throws -> URL {
        let url = tempURL(fileName: fileName)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: pdfFormat(password: password)
        )

        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()

            drawDocument(
                document,
                in: ctx.cgContext,
                addWatermark: addWatermark
            )
        }

        return url
    }
    
    func drawDocument(_ document: SharePreviewModel, in ctx: CGContext, addWatermark: Bool) {
        switch document.documentType {
        case .documents:
            drawRegular(document, ctx, addWatermark)
        case .idCard, .driverLicense:
            drawID(document, ctx, addWatermark)
        case .passport:
            drawPassport(document, ctx, addWatermark)
        default:
            break
        }
    }
    
    private func drawRegular(_ document: SharePreviewModel, _ ctx: CGContext, _ watermark: Bool) {
        guard let image = document.frames.first?.preview else { return }
        let rect = contentRect()

        let fittedRect = aspectFitRect(
            imageSize: image.size,
            inRect: rect
        )

        drawImage(image, in: fittedRect, ctx: ctx)

        if watermark {
            WatermarkRenderer.draw(
                in: ctx,
                pageSize: pageSize
            )
        }
    }
    
    private func drawID(_ document: SharePreviewModel, _ ctx: CGContext, _ watermark: Bool) {
        let images = document.frames.compactMap { $0.preview }
        guard !images.isEmpty else { return }

        let imageSize = CGSize(width: 256, height: 162)
        let spacing: CGFloat = 32

        let totalHeight =
            imageSize.height * CGFloat(images.count) +
            spacing * CGFloat(images.count - 1)

        let startY = (pageSize.height - totalHeight) / 2

        for (index, image) in images.enumerated() {

            let y =
                startY +
                CGFloat(index) * (imageSize.height + spacing)

            let rect = CGRect(
                x: (pageSize.width - imageSize.width) / 2,
                y: y,
                width: imageSize.width,
                height: imageSize.height
            )

            drawImage(image, in: rect, ctx: ctx)
        }

        if watermark {
            WatermarkRenderer.draw(in: ctx, pageSize: pageSize)
        }
    }
    
    private func drawPassport(_ document: SharePreviewModel,_ ctx: CGContext,_ watermark: Bool) {
        guard let image = document.frames.first?.preview else { return }
        let size = CGSize(width: 360, height: 250)

        let rect = CGRect(
            x: (pageSize.width - size.width) / 2,
            y: (pageSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )

        drawImage(image, in: rect, ctx: ctx)

        if watermark {
            WatermarkRenderer.draw(in: ctx, pageSize: pageSize)
        }
    }
    
    private func drawImage(_ image: UIImage, in rect: CGRect,ctx: CGContext) {
        guard let cgImage = image.cgImage else { return }
        ctx.saveGState()

        ctx.translateBy(x: 0, y: pageSize.height)
        ctx.scaleBy(x: 1, y: -1)

        let flippedRect = CGRect(
            x: rect.origin.x,
            y: pageSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        ctx.draw(cgImage, in: flippedRect)
        ctx.restoreGState()
    }
    
    private func contentRect() -> CGRect {
        CGRect(
            x: pageMargin,
            y: pageMargin,
            width: pageSize.width - pageMargin * 2,
            height: pageSize.height - pageMargin * 2
        )
    }
    
    private func aspectFitRect(imageSize: CGSize, inRect rect: CGRect) -> CGRect {
        let scale = min(
            rect.width / imageSize.width,
            rect.height / imageSize.height
        )

        let width = imageSize.width * scale
        let height = imageSize.height * scale

        let x = rect.midX - width / 2
        let y = rect.midY - height / 2

        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func pdfFormat(password: String?) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()

        guard let password else { return format }

        format.documentInfo = [
            kCGPDFContextUserPassword as String: password,
            kCGPDFContextOwnerPassword as String: password
        ]

        return format
    }
    
    private func tempURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")
    }
}

// MARK: - WatermarkRendere

extension PDFRendererService {
    enum WatermarkRenderer {
        private static let logoSize = CGSize(width: 14, height: 14)
        private static let padding: CGFloat = 3
        private static let cornerRadius: CGFloat = 4
        private static let margin: CGFloat = 8
        private static let spacing: CGFloat = 4

        private static let font = UIFont.systemFont(
            ofSize: 8,
            weight: .semibold
        )

        private static let text = "SmartScan Ai"

        private static let backgroundColor = UIColor(
            red: 247/255,
            green: 247/255,
            blue: 247/255,
            alpha: 1
        )

        static func draw(
            in ctx: CGContext,
            pageSize: CGSize
        ) {
            guard let logo = UIImage(named: "appMiniLogo_image") else {
                return
            }

            UIGraphicsPushContext(ctx)

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]

            let textSize = text.size(withAttributes: attributes)

            let contentWidth =
                logoSize.width +
                spacing +
                textSize.width

            let contentHeight =
                max(logoSize.height, textSize.height)

            let boxWidth = contentWidth + padding * 2
            let boxHeight = contentHeight + padding * 2

            let boxRect = CGRect(
                x: pageSize.width - boxWidth - margin,
                y: pageSize.height - boxHeight - margin,
                width: boxWidth,
                height: boxHeight
            )

            let path = UIBezierPath(
                roundedRect: boxRect,
                cornerRadius: cornerRadius
            )

            backgroundColor.setFill()
            path.fill()

            let logoRect = CGRect(
                x: boxRect.minX + padding,
                y: boxRect.minY + padding + (contentHeight - logoSize.height)/2,
                width: logoSize.width,
                height: logoSize.height
            )

            logo.draw(in: logoRect)

            let textRect = CGRect(
                x: logoRect.maxX + spacing,
                y: boxRect.minY + padding + (contentHeight - textSize.height)/2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(
                in: textRect,
                withAttributes: attributes
            )

            UIGraphicsPopContext()
        }
        
        static func drawUIKit(in ctx: CGContext, pageSize: CGSize) {
            guard let logo = UIImage(named: "appMiniLogo_image") else { return }

            // SCALE относительно страницы
            let scale = pageSize.width / 375.0   // 375 = базовая ширина iPhone

            let logoSize = CGSize(width: 14 * scale, height: 14 * scale)
            let padding: CGFloat = 3 * scale
            let spacing: CGFloat = 4 * scale
            let margin: CGFloat = 8 * scale
            let cornerRadius: CGFloat = 4 * scale

            let font = UIFont.systemFont(
                ofSize: 8 * scale,
                weight: .semibold
            )

            let text = "SmartScan Ai"

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black
            ]

            let textSize = text.size(withAttributes: textAttributes)

            let contentWidth =
                logoSize.width +
                spacing +
                textSize.width

            let contentHeight =
                max(logoSize.height, textSize.height)

            let boxWidth = contentWidth + padding * 2
            let boxHeight = contentHeight + padding * 2

            let boxRect = CGRect(
                x: pageSize.width - boxWidth - margin,
                y: pageSize.height - boxHeight - margin,
                width: boxWidth,
                height: boxHeight
            )

            let path = UIBezierPath(
                roundedRect: boxRect,
                cornerRadius: cornerRadius
            )

            backgroundColor.setFill()
            path.fill()

            let logoRect = CGRect(
                x: boxRect.minX + padding,
                y: boxRect.minY + padding + (contentHeight - logoSize.height)/2,
                width: logoSize.width,
                height: logoSize.height
            )

            logo.draw(in: logoRect)

            let textRect = CGRect(
                x: logoRect.maxX + spacing,
                y: boxRect.minY + padding + (contentHeight - textSize.height)/2,
                width: textSize.width,
                height: textSize.height
            )

            text.draw(in: textRect, withAttributes: textAttributes)
        }
    }
}
