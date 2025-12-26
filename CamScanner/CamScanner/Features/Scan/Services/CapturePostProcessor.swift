import UIKit
import CoreGraphics

/// Пост-обработка уже сделанного снимка:
/// - (опционально) crop/deskew по quad из превью (масштабируем в координаты photo + учитываем rotationAngle)
/// - downscale ПОСЛЕ кропа
final class CapturePostProcessor {

    func process(
        image: UIImage,
        previewQuad: Quadrilateral?,
        previewImageSize: CGSize,
        autoCrop: Bool,
        quality: QualityPreset
    ) -> UIImage {

        var final = image

        if autoCrop,
           let previewQuad,
           previewImageSize.width > 0,
           previewImageSize.height > 0 {

            let angle = SmartCropper.rotationAngle(for: final.imageOrientation)

            // quad из детектора (preview) -> координаты реального фото (с учётом rotationAngle как в WeScan)
            let quadInImageSpace = previewQuad.scale(previewImageSize, final.size, withRotationAngle: angle)

            if let cropped = SmartCropper.cropAndDeskew(image: final, quad: quadInImageSpace) {
                final = cropped
            }
        }

        // downscale ПОСЛЕ кропа
        final = final.downscaled(maxDimension: quality.maxDimension)
        return final
    }
}
