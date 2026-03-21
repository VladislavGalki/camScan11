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
        guard let original = document.frames.first?.preview else {
            return
        }

        let image = ImageCompressionService.shared.compress(
            original,
            maxDimension: 1240,
            quality: 0.75
        )

        let rect = contentRect()

        let fittedRect =
            aspectFitRect(
                imageSize: image.size,
                inRect: rect
            )

        drawImage(
            image,
            in: fittedRect,
            ctx: ctx
        )

        TextItemRenderer.drawForDocuments(
            items: document.textItems,
            in: ctx,
            fittedRect: fittedRect,
            cellHeight: document.cellHeight
        )

        if watermark {
            WatermarkRenderer.draw(
                in: ctx,
                pageSize: pageSize
            )
        }
    }

    private func drawID(_ document: SharePreviewModel, _ ctx: CGContext, _ watermark: Bool) {
        let originals = document.frames.compactMap(\.preview)
        guard !originals.isEmpty else { return }

        let images = originals.map {
            ImageCompressionService.shared.compress(
                $0,
                maxDimension: 842,
                quality: 0.72
            )
        }

        let imageWidth = pageSize.width * 0.75
        let aspect: CGFloat = 162.0 / 256.0
        let imageHeight = imageWidth * aspect
        let spacing: CGFloat = pageSize.height * 0.04

        let totalHeight =
            CGFloat(images.count) * imageHeight +
            CGFloat(images.count - 1) * spacing

        let startY =
            (pageSize.height - totalHeight) / 2

        var y = startY
        var imageRects: [CGRect] = []

        for image in images {

            let rect = CGRect(
                x: (pageSize.width - imageWidth) / 2,
                y: y,
                width: imageWidth,
                height: imageHeight
            )

            drawImage(image, in: rect, ctx: ctx)
            imageRects.append(rect)

            y += imageHeight + spacing
        }

        TextItemRenderer.drawForIDCard(
            items: document.textItems,
            in: ctx,
            imageRects: imageRects,
            cellHeight: document.cellHeight
        )

        if watermark {
            WatermarkRenderer.draw(
                in: ctx,
                pageSize: pageSize
            )
        }
    }

    private func drawPassport(_ document: SharePreviewModel, _ ctx: CGContext, _ watermark: Bool) {
        guard let original = document.frames.first?.preview else {
            return
        }

        let image = ImageCompressionService.shared.compress(
            original,
            maxDimension: 842,
            quality: 0.72
        )

        let imageWidth = pageSize.width * 0.8

        let aspect =
            image.size.height / image.size.width

        let imageHeight =
            imageWidth * aspect

        let rect = CGRect(
            x: (pageSize.width - imageWidth) / 2,
            y: (pageSize.height - imageHeight) / 2,
            width: imageWidth,
            height: imageHeight
        )

        drawImage(image, in: rect, ctx: ctx)

        TextItemRenderer.drawForPassport(
            items: document.textItems,
            in: ctx,
            imageRect: rect,
            cellHeight: document.cellHeight
        )

        if watermark {
            WatermarkRenderer.draw(
                in: ctx,
                pageSize: pageSize
            )
        }
    }

    private func drawImage(_ image: UIImage, in rect: CGRect, ctx: CGContext) {
        guard let cgImage = image.cgImage else {
            return
        }

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

// MARK: - TextItemRenderer

extension PDFRendererService {
    enum TextItemRenderer {
        /// Fixed cell width from AddTextCarouselController
        private static let cellWidth: CGFloat = 322

        /// Screen imageView sizes from AddTextPageCell.configure
        private static let idCardImageViewSize = CGSize(width: 171, height: 108)
        private static let idCardSpacing: CGFloat = 8
        private static let passportImageViewSize = CGSize(width: 360, height: 250)

        // MARK: - Public

        static func drawForDocuments(
            items: [DocumentTextItem],
            in ctx: CGContext,
            fittedRect: CGRect,
            cellHeight providedCellHeight: CGFloat = 0
        ) {
            guard !items.isEmpty else { return }

            let cellHeight = providedCellHeight > 0 ? providedCellHeight : deriveCellHeight(from: items)
            let imageHeightInCell = cellWidth * fittedRect.height / fittedRect.width

            let screenContent = CGRect(
                x: 0,
                y: (cellHeight - imageHeightInCell) / 2,
                width: cellWidth,
                height: imageHeightInCell
            )

            print("🖨️ Renderer | drawForDocuments: items=\(items.count) fittedRect=\(fittedRect)")
            print("🖨️ Renderer |   cellWidth=\(cellWidth) cellHeight=\(cellHeight) imageHeightInCell=\(imageHeightInCell)")
            print("🖨️ Renderer |   screenContent=\(screenContent)")

            drawMapped(items, in: ctx, cellHeight: cellHeight,
                       screenContent: screenContent, renderRect: fittedRect)
        }

        static func drawForIDCard(
            items: [DocumentTextItem],
            in ctx: CGContext,
            imageRects: [CGRect],
            cellHeight providedCellHeight: CGFloat = 0
        ) {
            guard !items.isEmpty, !imageRects.isEmpty else { return }

            let cellHeight = providedCellHeight > 0 ? providedCellHeight : deriveCellHeight(from: items)
            let imgSize = idCardImageViewSize
            let imageCount = imageRects.count

            // Build screen image rects (same layout as AddTextPageCell)
            let totalH = CGFloat(imageCount) * imgSize.height
                + CGFloat(imageCount - 1) * idCardSpacing
            let originX = (cellWidth - imgSize.width) / 2
            var y = (cellHeight - totalH) / 2
            var screenRects: [CGRect] = []
            for _ in 0..<imageCount {
                screenRects.append(CGRect(x: originX, y: y,
                                          width: imgSize.width, height: imgSize.height))
                y += imgSize.height + idCardSpacing
            }

            print("🖨️ Renderer | drawForIDCard: items=\(items.count) imageRects=\(imageRects)")
            print("🖨️ Renderer |   cellWidth=\(cellWidth) cellHeight=\(cellHeight)")
            print("🖨️ Renderer |   screenRects=\(screenRects)")

            drawPerImage(items, in: ctx, cellHeight: cellHeight,
                         screenRects: screenRects, renderRects: imageRects)
        }

        static func drawForPassport(
            items: [DocumentTextItem],
            in ctx: CGContext,
            imageRect: CGRect,
            cellHeight providedCellHeight: CGFloat = 0
        ) {
            guard !items.isEmpty else { return }

            let cellHeight = providedCellHeight > 0 ? providedCellHeight : deriveCellHeight(from: items)

            // Compute visible image rect on screen (aspect fit inside 360×250 imageView)
            let ivSize = passportImageViewSize
            let imageAspect = imageRect.width / imageRect.height

            let visibleSize: CGSize
            if imageAspect > ivSize.width / ivSize.height {
                visibleSize = CGSize(width: ivSize.width,
                                     height: ivSize.width / imageAspect)
            } else {
                visibleSize = CGSize(width: ivSize.height * imageAspect,
                                     height: ivSize.height)
            }

            // ImageView centered in cell → visible image centered in imageView
            let ivOriginX = (cellWidth - ivSize.width) / 2
            let ivOriginY = (cellHeight - ivSize.height) / 2
            let visOriginX = ivOriginX + (ivSize.width - visibleSize.width) / 2
            let visOriginY = ivOriginY + (ivSize.height - visibleSize.height) / 2

            let screenContent = CGRect(origin: CGPoint(x: visOriginX, y: visOriginY),
                                       size: visibleSize)

            print("🖨️ Renderer | drawForPassport: items=\(items.count) imageRect=\(imageRect)")
            print("🖨️ Renderer |   cellWidth=\(cellWidth) cellHeight=\(cellHeight) imageAspect=\(imageAspect)")
            print("🖨️ Renderer |   ivSize=\(ivSize) visibleSize=\(visibleSize)")
            print("🖨️ Renderer |   screenContent=\(screenContent)")

            drawMapped(items, in: ctx, cellHeight: cellHeight,
                       screenContent: screenContent, renderRect: imageRect)
        }

        // MARK: - Core drawing (single rect mapping)

        private static func drawMapped(
            _ items: [DocumentTextItem],
            in ctx: CGContext,
            cellHeight: CGFloat,
            screenContent: CGRect,
            renderRect: CGRect
        ) {
            UIGraphicsPushContext(ctx)

            let scaleX = renderRect.width / screenContent.width
            let scaleY = renderRect.height / screenContent.height

            print("🖨️ Renderer | drawMapped: scaleX=\(scaleX) scaleY=\(scaleY)")

            for item in items {
                let cellX = item.centerX * cellWidth
                let cellY = item.centerY * cellHeight
                let pdfX = renderRect.origin.x + (cellX - screenContent.origin.x) * scaleX
                let pdfY = renderRect.origin.y + (cellY - screenContent.origin.y) * scaleY
                print("🖨️ Renderer |   \"\(item.text)\" cellPos=(\(cellX), \(cellY)) → pdfPos=(\(pdfX), \(pdfY)) fontScale=\(scaleX)")

                drawItemAt(item, centerX: pdfX, centerY: pdfY,
                           cellHeight: cellHeight, scaleX: scaleX, scaleY: scaleY)
            }

            UIGraphicsPopContext()
        }

        // MARK: - Core drawing (per-image mapping for ID cards)

        private static func drawPerImage(
            _ items: [DocumentTextItem],
            in ctx: CGContext,
            cellHeight: CGFloat,
            screenRects: [CGRect],
            renderRects: [CGRect]
        ) {
            UIGraphicsPushContext(ctx)

            for item in items {
                let cellX = item.centerX * cellWidth
                let cellY = item.centerY * cellHeight

                // Find the closest screen image to this text item
                var bestIdx = 0
                var bestDist = CGFloat.greatestFiniteMagnitude
                for (i, sr) in screenRects.enumerated() {
                    let d = abs(cellY - sr.midY)
                    if d < bestDist { bestDist = d; bestIdx = i }
                }

                let sr = screenRects[bestIdx]
                let rr = renderRects[bestIdx]
                let scaleX = rr.width / sr.width
                let scaleY = rr.height / sr.height

                let pdfX = rr.origin.x + (cellX - sr.origin.x) * scaleX
                let pdfY = rr.origin.y + (cellY - sr.origin.y) * scaleY

                print("🖨️ Renderer |   \"\(item.text)\" cellPos=(\(cellX), \(cellY)) → img[\(bestIdx)] pdfPos=(\(pdfX), \(pdfY)) scale=(\(scaleX), \(scaleY))")

                drawItemAt(item, centerX: pdfX, centerY: pdfY,
                           cellHeight: cellHeight, scaleX: scaleX, scaleY: scaleY)
            }

            UIGraphicsPopContext()
        }

        // MARK: - Single item drawing

        private static func drawItemAt(
            _ item: DocumentTextItem,
            centerX: CGFloat,
            centerY: CGFloat,
            cellHeight: CGFloat,
            scaleX: CGFloat,
            scaleY: CGFloat
        ) {
            let blockWidth = item.width * cellWidth * scaleX
            let blockHeight = item.height * cellHeight * scaleY

            let fontScale = scaleX
            let padding: CGFloat = 8 * fontScale
            let contentWidth = max(blockWidth - padding * 2, 0)
            let contentHeight = max(blockHeight - padding * 2, 0)

            let fontSize = item.style.fontSize * fontScale
            let letterSpacing = item.style.letterSpacing * fontScale

            let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
            let color = UIColor(rgbaHex: item.style.textColorHex) ?? .black

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineSpacing = 0

            switch item.style.alignment {
            case .left:   paragraphStyle.alignment = .left
            case .center: paragraphStyle.alignment = .center
            case .right:  paragraphStyle.alignment = .right
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .kern: letterSpacing,
                .paragraphStyle: paragraphStyle
            ]

            let contentRect = CGRect(
                x: centerX - blockWidth / 2 + padding,
                y: centerY - blockHeight / 2 + padding,
                width: contentWidth,
                height: contentHeight
            )

            let clipRect = CGRect(
                x: centerX - blockWidth / 2,
                y: centerY - blockHeight / 2,
                width: blockWidth,
                height: blockHeight
            )

            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.saveGState()

            if item.rotation != 0 {
                context.translateBy(x: centerX, y: centerY)
                context.rotate(by: item.rotation * .pi / 180)
                context.translateBy(x: -centerX, y: -centerY)
            }

            context.clip(to: clipRect)

            (item.text as NSString).draw(
                with: contentRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )

            context.restoreGState()
        }

        // MARK: - Cell height derivation

        private static func deriveCellHeight(from items: [DocumentTextItem]) -> CGFloat {
            guard let item = items.first, item.height > 0.001 else {
                print("🖨️ Renderer | deriveCellHeight: no valid items, fallback=456")
                return 456
            }

            let widthPoints = item.width * cellWidth
            let heightPoints = measureTextBlockHeight(item: item, widthPoints: widthPoints)

            let derived = heightPoints / item.height
            print("🖨️ Renderer | deriveCellHeight: text=\"\(item.text)\" widthPts=\(widthPoints) heightPts=\(heightPoints) item.height=\(item.height) → derived=\(derived)")
            guard derived > 100, derived < 2000 else {
                print("🖨️ Renderer | deriveCellHeight: out of range, fallback=456")
                return 456
            }
            return derived
        }

        private static func measureTextBlockHeight(item: DocumentTextItem, widthPoints: CGFloat) -> CGFloat {
            let horizontalInset: CGFloat = 8
            let verticalInset: CGFloat = 8
            let minHeight: CGFloat = 44

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: item.style.fontSize, weight: .regular),
                .kern: item.style.letterSpacing,
                .paragraphStyle: paragraph
            ]

            let sourceText = item.text.isEmpty ? " " : item.text
            let attributed = NSAttributedString(string: sourceText, attributes: attributes)

            let singleLineRect = attributed.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            let idealWidth = ceil(singleLineRect.width)
            let availableWidth = max(widthPoints - horizontalInset * 2, 1)
            let targetWidth = min(idealWidth, availableWidth)

            let wrappedRect = attributed.boundingRect(
                with: CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            return max(ceil(wrappedRect.height) + verticalInset * 2, minHeight)
        }
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
