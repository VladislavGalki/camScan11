import Foundation
import UIKit

public enum RotationDirection {
    case left
    case right
}

final class RotationService {
    static let shared = RotationService()
    
    private init() {}
    
    func rotateRight(frame: CapturedFrame) -> CapturedFrame {
        rotate(frame: frame, direction: .right)
    }

    func rotateLeft(frame: CapturedFrame) -> CapturedFrame {
        rotate(frame: frame, direction: .left)
    }
}

private extension RotationService {
    func rotate(
        frame: CapturedFrame,
        direction: RotationDirection
    ) -> CapturedFrame {

        var newFrame = frame

        if let original = frame.original {
            newFrame.original = rotateImage(original, direction: direction)
        }

        if let preview = frame.preview {
            newFrame.preview = rotateImage(preview, direction: direction)
        }

        if let quad = frame.quad,
           let original = frame.original {

            newFrame.quad = quad
                .rotated90(direction: direction, inImageOfSize: original.size)
                .reorganized()
        }

        if let base = frame.drawingBase {
            newFrame.drawingBase = rotateImage(base, direction: direction)
        }

        return newFrame
    }
    
    func rotateImage(
        _ image: UIImage,
        direction: RotationDirection
    ) -> UIImage? {

        let oldSize = image.size
        let newSize = CGSize(width: oldSize.height, height: oldSize.width)

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { ctx in

            let c = ctx.cgContext

            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)

            switch direction {
            case .right:
                c.rotate(by: .pi / 2)
            case .left:
                c.rotate(by: -.pi / 2)
            }

            c.translateBy(x: -oldSize.width / 2, y: -oldSize.height / 2)

            image.draw(in: CGRect(origin: .zero, size: oldSize))
        }
    }
}
