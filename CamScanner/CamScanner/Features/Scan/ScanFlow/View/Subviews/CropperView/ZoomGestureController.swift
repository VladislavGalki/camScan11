import Foundation
import UIKit

final class ZoomGestureController {

    private let image: UIImage
    private let magnifier: CropMagnifierView
    private let quadView: QuadrilateralView
    private var previousPanPosition: CGPoint?
    private var closestCorner: CornerPosition?

    init(image: UIImage, quadView: QuadrilateralView, magnifier: CropMagnifierView) {
        self.image = image
        self.quadView = quadView
        self.magnifier = magnifier
    }

    @objc func handle(pan: UIGestureRecognizer) {
        guard let drawnQuad = quadView.quad else { return }

        if pan.state == .ended {
            previousPanPosition = nil
            closestCorner = nil
            magnifier.isHidden = true
            return
        }

        magnifier.isHidden = false
        let position = pan.location(in: quadView)

        magnifier.center = CGPoint(
            x: quadView.frame.minX + position.x,
            y: quadView.frame.minY + position.y - 100
        )

        let previous = previousPanPosition ?? position
        let corner = closestCorner ?? position.closestCornerFrom(quad: drawnQuad)

        let offset = CGAffineTransform(
            translationX: position.x - previous.x,
            y: position.y - previous.y
        )

        let cornerView = quadView.cornerViewForCornerPosition(position: corner)
        let draggedCenter = cornerView.center.applying(offset)

        quadView.moveCorner(cornerView: cornerView, atPoint: draggedCenter)

        previousPanPosition = position
        closestCorner = corner

        let scale = image.size.width / quadView.bounds.size.width
        let scaledPoint = CGPoint(x: draggedCenter.x * scale, y: draggedCenter.y * scale)

        if let zoomedImage = image.scaledImage(atPoint: scaledPoint, scaleFactor: 1, targetSize: quadView.bounds.size) {
            magnifier.update(image: zoomedImage, corner: corner, quad: drawnQuad)
        }
    }
}
