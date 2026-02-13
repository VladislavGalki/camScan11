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
        let position = pan.location(in: quadView)
        
        switch pan.state {
        case .began:
            guard let hitCorner = hitTestCorner(at: position) else { return }

            closestCorner = hitCorner
            previousPanPosition = position

            magnifier.center = CGPoint(
                x: quadView.frame.minX + position.x,
                y: quadView.frame.minY + position.y - 100
            )

            let cornerView = quadView.cornerViewForCornerPosition(position: hitCorner)

            updateMagnifierImage(
                at: cornerView.center,
                corner: hitCorner,
                drawnQuad: drawnQuad
            )

            magnifier.alpha = 0
            magnifier.isHidden = false

            UIView.animate(withDuration: 0.15) { [weak self] in
                self?.magnifier.alpha = 1
            }

        case .changed:
            guard let corner = closestCorner,
                  let previous = previousPanPosition else { return }

            let offset = CGAffineTransform(
                translationX: position.x - previous.x,
                y: position.y - previous.y
            )

            let cornerView = quadView.cornerViewForCornerPosition(position: corner)
            let draggedCenter = cornerView.center.applying(offset)

            quadView.moveCorner(
                cornerView: cornerView,
                atPoint: draggedCenter
            )

            magnifier.center = CGPoint(
                x: quadView.frame.minX + position.x,
                y: quadView.frame.minY + position.y - 100
            )

            updateMagnifierImage(
                at: draggedCenter,
                corner: corner,
                drawnQuad: drawnQuad
            )

            previousPanPosition = position
        default:
            previousPanPosition = nil
            closestCorner = nil
            magnifier.isHidden = true
            magnifier.center = .zero
        }
    }
    
    private func updateMagnifierImage(
        at draggedCenter: CGPoint,
        corner: CornerPosition,
        drawnQuad: Quadrilateral
    ) {
        let scale = image.size.width / quadView.bounds.size.width

        let scaledPoint = CGPoint(
            x: draggedCenter.x * scale,
            y: draggedCenter.y * scale
        )

        if let zoomedImage = image.scaledImage(
            atPoint: scaledPoint,
            scaleFactor: 1,
            targetSize: quadView.bounds.size
        ) {
            magnifier.update(
                image: zoomedImage,
                corner: corner,
                quad: drawnQuad
            )
        }
    }
    
    private func hitTestCorner(at point: CGPoint) -> CornerPosition? {
        let hitRadius: CGFloat = 30

        for corner in CornerPosition.allCases {
            let view = quadView.cornerViewForCornerPosition(position: corner)
            
            if view.center.distanceTo(point: point) <= hitRadius {
                return corner
            }
        }

        return nil
    }
}
