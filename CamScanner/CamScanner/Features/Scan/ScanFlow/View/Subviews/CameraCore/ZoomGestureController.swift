//
//  ZoomGestureController.swift
//  (YourApp)
//
//  Based on WeScan
//

import Foundation
import UIKit

final class ZoomGestureController {

    private let image: UIImage
    private let quadView: QuadrilateralView
    private var previousPanPosition: CGPoint?
    private var closestCorner: CornerPosition?

    init(image: UIImage, quadView: QuadrilateralView) {
        self.image = image
        self.quadView = quadView
    }

    @objc func handle(pan: UIGestureRecognizer) {
        guard let drawnQuad = quadView.quad else {
            return
        }

        // Gesture ended -> reset state
        guard pan.state != .ended else {
            previousPanPosition = nil
            closestCorner = nil
            quadView.resetHighlightedCornerViews()
            return
        }

        let position = pan.location(in: quadView)

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

        // Zoom preview under the finger
        let scale = image.size.width / quadView.bounds.size.width
        let scaledPoint = CGPoint(x: draggedCenter.x * scale, y: draggedCenter.y * scale)

        guard let zoomedImage = image.scaledImage(
            atPoint: scaledPoint,
            scaleFactor: 2.5,
            targetSize: quadView.bounds.size
        ) else {
            return
        }

        quadView.highlightCornerAtPosition(position: corner, with: zoomedImage)
    }
}
