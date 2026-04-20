import UIKit
import CoreImage

final class CropRenderer {
    private let context = CIContext()
    init() {}

    func crop(image: UIImage, quad: Quadrilateral) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        
        let oriented = ciImage.oriented(
            forExifOrientation: Int32(cgOrientation.rawValue)
        )

        var cartesian = quad.toCartesian(withHeight: image.size.height)
        cartesian.reorganize()

        let corrected = oriented.applyingFilter(
            "CIPerspectiveCorrection",
            parameters: [
                "inputTopLeft": CIVector(cgPoint: cartesian.bottomLeft),
                "inputTopRight": CIVector(cgPoint: cartesian.bottomRight),
                "inputBottomLeft": CIVector(cgPoint: cartesian.topLeft),
                "inputBottomRight": CIVector(cgPoint: cartesian.topRight)
            ]
        )

        guard let cgImage = context.createCGImage(
            corrected,
            from: corrected.extent
        ) else { return nil }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}
