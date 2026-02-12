import UIKit
import CoreImage

enum SmartCropper {
    private static let ciContext = CIContext(options: nil)
    static func cropAndDeskew(image: UIImage, quad: Quadrilateral) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        var cartesianQuad = quad.toCartesian(withHeight: image.size.height)
        cartesianQuad.reorganize()

        let filtered = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianQuad.topRight)
        ])

        return UIImage.from(ciImage: filtered)
    }

    static func rotationAngle(for orientation: UIImage.Orientation) -> CGFloat {
        switch orientation {
        case .right: return .pi / 2
        case .up: return .pi
        default: return 0
        }
    }
}
