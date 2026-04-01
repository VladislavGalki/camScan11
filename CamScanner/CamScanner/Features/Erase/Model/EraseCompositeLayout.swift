import UIKit

struct EraseCompositeLayout {
    let canvasSize: CGSize
    let boxRects: [CGRect]
    let contentRects: [CGRect]

    static func make(
        documentType: DocumentTypeEnum,
        images: [UIImage],
        referenceWidth: CGFloat? = nil
    ) -> EraseCompositeLayout {
        let validImages = images.filter { $0.size.width > 0 && $0.size.height > 0 }

        guard !validImages.isEmpty else {
            return EraseCompositeLayout(canvasSize: .zero, boxRects: [], contentRects: [])
        }

        switch documentType {
        case .documents:
            let image = validImages[0]
            let rect = CGRect(origin: .zero, size: image.size)
            return EraseCompositeLayout(
                canvasSize: image.size,
                boxRects: [rect],
                contentRects: [rect]
            )

        case .passport:
            let image = validImages[0]
            let rect = CGRect(origin: .zero, size: image.size)
            return EraseCompositeLayout(
                canvasSize: image.size,
                boxRects: [rect],
                contentRects: [rect]
            )

        case .idCard, .driverLicense:
            let baseWidth = max(referenceWidth ?? validImages.map(\.size.width).max() ?? 171, 171)
            let scale = baseWidth / 171
            let boxSize = CGSize(width: 171 * scale, height: 108 * scale)
            let spacing = 8 * scale

            var boxRects: [CGRect] = []
            var contentRects: [CGRect] = []
            var y: CGFloat = 0

            for image in validImages {
                let boxRect = CGRect(origin: CGPoint(x: 0, y: y), size: boxSize)
                boxRects.append(boxRect)
                contentRects.append(aspectFitRect(for: image.size, in: boxRect))
                y += boxSize.height + spacing
            }

            if !boxRects.isEmpty {
                y -= spacing
            }

            return EraseCompositeLayout(
                canvasSize: CGSize(width: boxSize.width, height: y),
                boxRects: boxRects,
                contentRects: contentRects
            )

        case .qrCode:
            return EraseCompositeLayout(canvasSize: .zero, boxRects: [], contentRects: [])
        }
    }

    func compositeImage(with images: [UIImage], backgroundColor: UIColor = .white) -> UIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = images.first?.scale ?? UIScreen.main.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            for (image, rect) in zip(images, contentRects) {
                image.normalizedUp().draw(in: rect)
            }
        }
    }

    func split(_ composite: UIImage, originalImages: [UIImage]) -> [UIImage] {
        guard let cgImage = composite.normalizedUp().cgImage else { return [] }

        return zip(originalImages, contentRects).compactMap { originalImage, contentRect in
            let scaleX = CGFloat(cgImage.width) / composite.size.width
            let scaleY = CGFloat(cgImage.height) / composite.size.height
            let cropRect = CGRect(
                x: contentRect.minX * scaleX,
                y: contentRect.minY * scaleY,
                width: contentRect.width * scaleX,
                height: contentRect.height * scaleY
            ).integral

            guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

            let croppedImage = UIImage(
                cgImage: cropped,
                scale: composite.scale,
                orientation: .up
            )

            let format = UIGraphicsImageRendererFormat()
            format.scale = originalImage.scale
            format.opaque = true

            let renderer = UIGraphicsImageRenderer(size: originalImage.size, format: format)
            return renderer.image { _ in
                UIColor.white.setFill()
                UIBezierPath(rect: CGRect(origin: .zero, size: originalImage.size)).fill()
                croppedImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
            }
        }
    }
}

private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
    guard imageSize.width > 0,
          imageSize.height > 0,
          bounds.width > 0,
          bounds.height > 0 else { return .zero }

    let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let origin = CGPoint(
        x: bounds.minX + (bounds.width - size.width) / 2,
        y: bounds.minY + (bounds.height - size.height) / 2
    )
    return CGRect(origin: origin, size: size)
}
