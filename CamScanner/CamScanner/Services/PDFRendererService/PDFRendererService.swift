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
            fittedRect: fittedRect
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

        for image in images {

            let rect = CGRect(
                x: (pageSize.width - imageWidth) / 2,
                y: y,
                width: imageWidth,
                height: imageHeight
            )

            drawImage(image, in: rect, ctx: ctx)

            y += imageHeight + spacing
        }

        let boundingRect = CGRect(
            x: (pageSize.width - imageWidth) / 2,
            y: startY,
            width: imageWidth,
            height: totalHeight
        )

        TextItemRenderer.drawForIDCard(
            items: document.textItems,
            in: ctx,
            contentRect: boundingRect
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
            imageRect: rect
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

        /// Screen content sizes from AddTextPageCell.configure
        private static let idCardContentSize = CGSize(width: 171, height: 108 * 2 + 8)
        private static let passportContentSize = CGSize(width: 360, height: 250)

        // MARK: - Public

        static func drawForDocuments(
            items: [DocumentTextItem],
            in ctx: CGContext,
            fittedRect: CGRect
        ) {
            guard !items.isEmpty else { return }

            let cellHeight = deriveCellHeight(from: items)
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

            drawItems(items, in: ctx, cellHeight: cellHeight,
                      screenContent: screenContent, renderRect: fittedRect)
        }

        static func drawForIDCard(
            items: [DocumentTextItem],
            in ctx: CGContext,
            contentRect: CGRect
        ) {
            guard !items.isEmpty else { return }

            let cellHeight = deriveCellHeight(from: items)

            let screenContent = CGRect(
                x: (cellWidth - idCardContentSize.width) / 2,
                y: (cellHeight - idCardContentSize.height) / 2,
                width: idCardContentSize.width,
                height: idCardContentSize.height
            )

            print("🖨️ Renderer | drawForIDCard: items=\(items.count) contentRect=\(contentRect)")
            print("🖨️ Renderer |   cellWidth=\(cellWidth) cellHeight=\(cellHeight) idCardContentSize=\(idCardContentSize)")
            print("🖨️ Renderer |   screenContent=\(screenContent)")

            drawItems(items, in: ctx, cellHeight: cellHeight,
                      screenContent: screenContent, renderRect: contentRect)
        }

        static func drawForPassport(
            items: [DocumentTextItem],
            in ctx: CGContext,
            imageRect: CGRect
        ) {
            guard !items.isEmpty else { return }

            let cellHeight = deriveCellHeight(from: items)

            let screenContent = CGRect(
                x: (cellWidth - passportContentSize.width) / 2,
                y: (cellHeight - passportContentSize.height) / 2,
                width: passportContentSize.width,
                height: passportContentSize.height
            )

            print("🖨️ Renderer | drawForPassport: items=\(items.count) imageRect=\(imageRect)")
            print("🖨️ Renderer |   cellWidth=\(cellWidth) cellHeight=\(cellHeight) passportContentSize=\(passportContentSize)")
            print("🖨️ Renderer |   screenContent=\(screenContent)")

            drawItems(items, in: ctx, cellHeight: cellHeight,
                      screenContent: screenContent, renderRect: imageRect)
        }

        // MARK: - Core drawing

        private static func drawItems(
            _ items: [DocumentTextItem],
            in ctx: CGContext,
            cellHeight: CGFloat,
            screenContent: CGRect,
            renderRect: CGRect
        ) {
            UIGraphicsPushContext(ctx)

            let scaleX = renderRect.width / screenContent.width
            let scaleY = renderRect.height / screenContent.height

            print("🖨️ Renderer | drawItems: scaleX=\(scaleX) scaleY=\(scaleY) renderRect=\(renderRect)")

            for item in items {
                let cellX = item.centerX * cellWidth
                let cellY = item.centerY * cellHeight
                let pdfX = renderRect.origin.x + (cellX - screenContent.origin.x) * scaleX
                let pdfY = renderRect.origin.y + (cellY - screenContent.origin.y) * scaleY
                let blockW = item.width * cellWidth * scaleX
                let blockH = item.height * cellHeight * scaleY
                print("🖨️ Renderer |   \"\(item.text)\" cellPos=(\(cellX), \(cellY)) → pdfPos=(\(pdfX), \(pdfY)) blockSize=(\(blockW), \(blockH)) fontSize=\(item.style.fontSize)*\(scaleX)=\(item.style.fontSize * scaleX)")

                drawItem(
                    item,
                    cellHeight: cellHeight,
                    screenContent: screenContent,
                    renderRect: renderRect,
                    scaleX: scaleX,
                    scaleY: scaleY
                )
            }

            UIGraphicsPopContext()
        }

        private static func drawItem(
            _ item: DocumentTextItem,
            cellHeight: CGFloat,
            screenContent: CGRect,
            renderRect: CGRect,
            scaleX: CGFloat,
            scaleY: CGFloat
        ) {
            // Text position in cell coordinates (pts)
            let cellX = item.centerX * cellWidth
            let cellY = item.centerY * cellHeight

            // Map from cell coords → render coords through content alignment
            let centerX = renderRect.origin.x
                + (cellX - screenContent.origin.x) * scaleX
            let centerY = renderRect.origin.y
                + (cellY - screenContent.origin.y) * scaleY

            // Text block size scaled to render space
            let blockWidth = item.width * cellWidth * scaleX
            let blockHeight = item.height * cellHeight * scaleY

            // Use width-based scale for font (preserves line-break behavior)
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

        /// Derives the original cell height by reverse-engineering from a stored text item.
        /// item.height = measuredHeightPts / cellHeight  →  cellHeight = measuredHeightPts / item.height
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

        /// Replicates AddTextViewModel.measuredEditingSize height computation
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
