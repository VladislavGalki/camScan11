import UIKit

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

        // downscale для превью/дальнейшего пайплайна
        previewImage = previewImage.downscaled(maxDimension: quality.maxDimension)

        return CapturePostProcessOutput(
            original: original,
            preview: previewImage,
            autoQuadInImageSpace: usedQuad
        )
    }
}
