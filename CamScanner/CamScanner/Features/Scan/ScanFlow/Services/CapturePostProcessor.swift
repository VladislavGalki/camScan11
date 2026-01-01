import UIKit
import CoreImage

struct CapturePostProcessOutput {
    let original: UIImage
    let preview: UIImage
    let autoQuadInImageSpace: Quadrilateral?
}

final class CapturePostProcessor {

    func process(
        image: UIImage,
        previewQuad: Quadrilateral?,
        previewImageSize: CGSize,
        autoCrop: Bool,
        quality: QualityPreset
    ) -> CapturePostProcessOutput {

        let original = image
        var previewImage = image
        var usedQuad: Quadrilateral? = nil

        if autoCrop,
           let previewQuad,
           previewImageSize.width > 0,
           previewImageSize.height > 0 {

            let angle = SmartCropper.rotationAngle(for: previewImage.imageOrientation)
            let quadInImageSpace = previewQuad.scale(previewImageSize, previewImage.size, withRotationAngle: angle)

            if let cropped = SmartCropper.cropAndDeskew(image: previewImage, quad: quadInImageSpace) {
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

    // ✅ ID MODE: режем строго по рамке в preview, без normalizedRect
    func processIdByFrame(
        image: UIImage,
        frameRectInPreview: CGRect,
        previewSize: CGSize,
        quality: QualityPreset
    ) -> CapturePostProcessOutput {

        // 1) нормализуем ориентацию по UIImage.imageOrientation (получаем .up)
        let fixed = image.normalizedUp()

        print("🪪 imageSize =", fixed.size, "orientation =", fixed.imageOrientation)
        print("🪪 previewSize =", previewSize)
        print("🪪 frameRect =", frameRectInPreview)

        guard previewSize.width > 0, previewSize.height > 0 else {
            let preview = fixed.downscaled(maxDimension: quality.maxDimension)
            return .init(original: fixed, preview: preview, autoQuadInImageSpace: nil)
        }

        // 2) переводим rect из preview coords -> image coords (aspectFill)
        let imageRect = mapAspectFillRectFromPreviewToImage(
            rect: frameRectInPreview,
            previewSize: previewSize,
            imageSize: fixed.size
        ).integral

        let center = CGPoint(x: imageRect.midX, y: imageRect.midY)
        print("🪪 imageRect center =", center)
        print("🪪 mapped imageRect =", imageRect)

        // 3) режем UIImage (CGImage crop)
        let cropped = fixed.cropped(to: imageRect) ?? fixed
        let preview = cropped.downscaled(maxDimension: quality.maxDimension)

        return .init(original: cropped, preview: preview, autoQuadInImageSpace: nil)
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

        // rect в координатах scaledImage
        let scaledRect = CGRect(
            x: rect.origin.x + xOffset,
            y: rect.origin.y + yOffset,
            width: rect.size.width,
            height: rect.size.height
        )

        // обратно в image coords
        return CGRect(
            x: scaledRect.origin.x / scale,
            y: scaledRect.origin.y / scale,
            width: scaledRect.size.width / scale,
            height: scaledRect.size.height / scale
        )
    }
}
