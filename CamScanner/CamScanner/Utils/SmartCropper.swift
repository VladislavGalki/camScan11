//
//  SmartCropper.swift
//  CamScanner
//

import UIKit
import CoreImage

enum SmartCropper {

    private static let ciContext = CIContext(options: nil)

    /// Crop + deskew using quad from PREVIEW (already scaled into captured image pixel space).
    ///
    /// IMPORTANT:
    /// - `UIImage.cgImage` ignores orientation metadata, so we:
    ///   1) build CIImage from cgImage (raw pixels)
    ///   2) orient CIImage using UIImage orientation (to get "upright" pixels)
    ///   3) rotate quad points into that oriented space
    ///   4) apply CIPerspectiveCorrection
    static func cropAndDeskew(image: UIImage, quad: Quadrilateral) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Нормализуем ориентацию как WeScan (вшиваем orientation в пиксели)
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)
        let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))

        // Cartesian + reorganize как WeScan
        var cartesianQuad = quad.toCartesian(withHeight: image.size.height)
        cartesianQuad.reorganize()

        // ВАЖНО: перестановка углов как в WeScan
        let filtered = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: cartesianQuad.bottomLeft),
            "inputTopRight": CIVector(cgPoint: cartesianQuad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: cartesianQuad.topLeft),
            "inputBottomRight": CIVector(cgPoint: cartesianQuad.topRight)
        ])

        return UIImage.from(ciImage: filtered)
    }

    /// Ровно та же логика угла, что у тебя в CaptureSessionManager.completeImageCapture
    static func rotationAngle(for orientation: UIImage.Orientation) -> CGFloat {
        switch orientation {
        case .right: return .pi / 2
        case .up: return .pi
        default: return 0
        }
    }
}
