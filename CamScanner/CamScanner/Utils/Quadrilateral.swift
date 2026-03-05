import AVFoundation
import CoreImage
import Foundation
import UIKit
import Vision


public struct Quadrilateral: Transformable, Hashable {
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomRight: CGPoint
    public var bottomLeft: CGPoint

    public var description: String {
        return "topLeft: \(topLeft), topRight: \(topRight), bottomRight: \(bottomRight), bottomLeft: \(bottomLeft)"
    }

    var path: UIBezierPath {
        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()

        return path
    }

    var perimeter: Double {
        let perimeter = topLeft.distanceTo(point: topRight)
            + topRight.distanceTo(point: bottomRight)
            + bottomRight.distanceTo(point: bottomLeft)
            + bottomLeft.distanceTo(point: topLeft)
        return Double(perimeter)
    }

    init(rectangleFeature: CIRectangleFeature) {
        self.topLeft = rectangleFeature.topLeft
        self.topRight = rectangleFeature.topRight
        self.bottomLeft = rectangleFeature.bottomLeft
        self.bottomRight = rectangleFeature.bottomRight
    }

    init(rectangleObservation: VNRectangleObservation) {
        self.topLeft = rectangleObservation.topLeft
        self.topRight = rectangleObservation.topRight
        self.bottomLeft = rectangleObservation.bottomLeft
        self.bottomRight = rectangleObservation.bottomRight
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public func applying(_ transform: CGAffineTransform) -> Quadrilateral {
        let quadrilateral = Quadrilateral(
            topLeft: topLeft.applying(transform),
            topRight: topRight.applying(transform),
            bottomRight: bottomRight.applying(transform),
            bottomLeft: bottomLeft.applying(transform)
        )

        return quadrilateral
    }

    func isWithin(_ distance: CGFloat, ofRectangleFeature rectangleFeature: Quadrilateral) -> Bool {
        let topLeftRect = topLeft.surroundingSquare(withSize: distance)
        if !topLeftRect.contains(rectangleFeature.topLeft) {
            return false
        }

        let topRightRect = topRight.surroundingSquare(withSize: distance)
        if !topRightRect.contains(rectangleFeature.topRight) {
            return false
        }

        let bottomRightRect = bottomRight.surroundingSquare(withSize: distance)
        if !bottomRightRect.contains(rectangleFeature.bottomRight) {
            return false
        }

        let bottomLeftRect = bottomLeft.surroundingSquare(withSize: distance)
        if !bottomLeftRect.contains(rectangleFeature.bottomLeft) {
            return false
        }

        return true
    }

    mutating func reorganize() {
        let points = [topLeft, topRight, bottomRight, bottomLeft]
        let ySortedPoints = sortPointsByYValue(points)

        guard ySortedPoints.count == 4 else {
            return
        }

        let topMostPoints = Array(ySortedPoints[0..<2])
        let bottomMostPoints = Array(ySortedPoints[2..<4])
        let xSortedTopMostPoints = sortPointsByXValue(topMostPoints)
        let xSortedBottomMostPoints = sortPointsByXValue(bottomMostPoints)

        guard xSortedTopMostPoints.count > 1,
            xSortedBottomMostPoints.count > 1 else {
                return
        }

        topLeft = xSortedTopMostPoints[0]
        topRight = xSortedTopMostPoints[1]
        bottomRight = xSortedBottomMostPoints[1]
        bottomLeft = xSortedBottomMostPoints[0]
    }

    func scale(_ fromSize: CGSize, _ toSize: CGSize, withRotationAngle rotationAngle: CGFloat = 0.0) -> Quadrilateral {
        var invertedFromSize = fromSize
        let rotated = rotationAngle != 0.0

        if rotated && rotationAngle != CGFloat.pi {
            invertedFromSize = CGSize(width: fromSize.height, height: fromSize.width)
        }

        var transformedQuad = self
        let invertedFromSizeWidth = invertedFromSize.width == 0 ? .leastNormalMagnitude : invertedFromSize.width
        let invertedFromSizeHeight = invertedFromSize.height == 0 ? .leastNormalMagnitude : invertedFromSize.height

        let scaleWidth = toSize.width / invertedFromSizeWidth
        let scaleHeight = toSize.height / invertedFromSizeHeight
        let scaledTransform = CGAffineTransform(scaleX: scaleWidth, y: scaleHeight)
        transformedQuad = transformedQuad.applying(scaledTransform)

        if rotated {
            let rotationTransform = CGAffineTransform(rotationAngle: rotationAngle)

            let fromImageBounds = CGRect(origin: .zero, size: fromSize).applying(scaledTransform).applying(rotationTransform)

            let toImageBounds = CGRect(origin: .zero, size: toSize)
            let translationTransform = CGAffineTransform.translateTransform(
                fromCenterOfRect: fromImageBounds,
                toCenterOfRect: toImageBounds
            )

            transformedQuad = transformedQuad.applyTransforms([rotationTransform, translationTransform])
        }

        return transformedQuad
    }

    private func sortPointsByYValue(_ points: [CGPoint]) -> [CGPoint] {
        return points.sorted { point1, point2 -> Bool in
            point1.y < point2.y
        }
    }

    private func sortPointsByXValue(_ points: [CGPoint]) -> [CGPoint] {
        return points.sorted { point1, point2 -> Bool in
            point1.x < point2.x
        }
    }
}

extension Quadrilateral {
    func scaled(aroundCenterBy factor: CGFloat) -> Quadrilateral {
        let c = CGPoint(
            x: (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4.0,
            y: (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4.0
        )

        func scale(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: c.x + (p.x - c.x) * factor,
                y: c.y + (p.y - c.y) * factor
            )
        }

        return Quadrilateral(
            topLeft: scale(topLeft),
            topRight: scale(topRight),
            bottomRight: scale(bottomRight),
            bottomLeft: scale(bottomLeft)
        )
    }

    func clamped(to rect: CGRect) -> Quadrilateral {
        func clampPoint(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: min(max(p.x, rect.minX), rect.maxX),
                y: min(max(p.y, rect.minY), rect.maxY)
            )
        }

        return Quadrilateral(
            topLeft: clampPoint(topLeft),
            topRight: clampPoint(topRight),
            bottomRight: clampPoint(bottomRight),
            bottomLeft: clampPoint(bottomLeft)
        )
    }
    
    func toCartesian(withHeight height: CGFloat) -> Quadrilateral {
        let topLeft = self.topLeft.cartesian(withHeight: height)
        let topRight = self.topRight.cartesian(withHeight: height)
        let bottomRight = self.bottomRight.cartesian(withHeight: height)
        let bottomLeft = self.bottomLeft.cartesian(withHeight: height)

        return Quadrilateral(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
    }
}

extension Quadrilateral: Equatable {
    public static func == (lhs: Quadrilateral, rhs: Quadrilateral) -> Bool {
        return lhs.topLeft == rhs.topLeft
            && lhs.topRight == rhs.topRight
            && lhs.bottomRight == rhs.bottomRight
            && lhs.bottomLeft == rhs.bottomLeft
    }
}
