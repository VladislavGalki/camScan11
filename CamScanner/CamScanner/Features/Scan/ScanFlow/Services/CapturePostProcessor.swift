import UIKit
import CoreImage

struct CapturePostProcessOutput {
    let original: UIImage            // FULL (для редактора)
    let preview: UIImage             // CROPPED (для превью)
    let autoQuadInImageSpace: Quadrilateral?  // quad рамки в координатах original
}

final class CapturePostProcessor {

    func process(
        image: UIImage,
        previewQuad: Quadrilateral?,
        previewImageSize: CGSize,
        autoMode: Bool,
        quality: QualityPreset
    ) -> CapturePostProcessOutput {

        let original = image
        var previewImage = image
        var usedQuad: Quadrilateral? = nil

        if autoMode,
           let previewQuad,
           previewImageSize.width > 0,
           previewImageSize.height > 0 {

            let angle = SmartCropper.rotationAngle(for: original.imageOrientation)
            let quadInImageSpace = previewQuad.scale(previewImageSize, original.size, withRotationAngle: angle)

            if let cropped = SmartCropper.cropAndDeskew(image: original, quad: quadInImageSpace) {
                previewImage = cropped
                usedQuad = quadInImageSpace
            } else {
                usedQuad = quadInImageSpace
            }
        }

        previewImage = previewImage.downscaled(maxDimension: quality.maxDimension)

        return CapturePostProcessOutput(
            original: original,
            preview: previewImage,
            autoQuadInImageSpace: usedQuad
        )
    }

    // ✅ ID MODE:
    // - original = FULL (для редактора)
    // - preview = CROPPED по рамке (для превью)
    // - autoQuadInImageSpace = quad рамки в координатах FULL
    func processIdByFrame(
        image: UIImage,
        frameRectInPreview: CGRect,
        previewSize: CGSize,
        quality: QualityPreset
    ) -> CapturePostProcessOutput {

        let full = image.normalizedUp()

        guard previewSize.width > 0, previewSize.height > 0 else {
            let preview = full.downscaled(maxDimension: quality.maxDimension)
            return .init(original: full, preview: preview, autoQuadInImageSpace: nil)
        }

        // rect рамки -> image coords (aspectFill)
        let imageRect = mapAspectFillRectFromPreviewToImage(
            rect: frameRectInPreview,
            previewSize: previewSize,
            imageSize: full.size
        ).integral

        // quad рамки в координатах full
        let quad = Quadrilateral(
            topLeft: CGPoint(x: imageRect.minX, y: imageRect.minY),
            topRight: CGPoint(x: imageRect.maxX, y: imageRect.minY),
            bottomRight: CGPoint(x: imageRect.maxX, y: imageRect.maxY),
            bottomLeft: CGPoint(x: imageRect.minX, y: imageRect.maxY)
        )

        // preview = cropped кусок (как CamScanner)
        let croppedForPreview = full.cropped(to: imageRect) ?? full
        let preview = croppedForPreview.downscaled(maxDimension: quality.maxDimension)

        return .init(original: full, preview: preview, autoQuadInImageSpace: quad)
    }

    // MARK: - Mapping (aspectFill)
    private func mapAspectFillRectFromPreviewToImage(
        rect: CGRect,
        previewSize: CGSize,
        imageSize: CGSize
    ) -> CGRect {

        let sx = previewSize.width / imageSize.width
        let sy = previewSize.height / imageSize.height
        let scale = max(sx, sy) // aspectFill

        let scaledImageSize = CGSize(width: imageSize.width * scale,
                                     height: imageSize.height * scale)

        let xOffset = (scaledImageSize.width - previewSize.width) / 2
        let yOffset = (scaledImageSize.height - previewSize.height) / 2

        let scaledRect = CGRect(
            x: rect.origin.x + xOffset,
            y: rect.origin.y + yOffset,
            width: rect.size.width,
            height: rect.size.height
        )

        return CGRect(
            x: scaledRect.origin.x / scale,
            y: scaledRect.origin.y / scale,
            width: scaledRect.size.width / scale,
            height: scaledRect.size.height / scale
        )
    }
}
