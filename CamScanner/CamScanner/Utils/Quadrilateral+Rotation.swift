import Foundation

public extension Quadrilateral {
    func reorganized() -> Quadrilateral {
        var quadrilateral = self
        quadrilateral.reorganize()
        return quadrilateral
    }
    
    func rotated90(
        direction: RotationDirection,
        inImageOfSize size: CGSize
    ) -> Quadrilateral {
        func rotationRight(_ p: CGPoint) -> CGPoint {
            CGPoint(x: size.height - p.y, y: p.x)
        }

        func rotationLeft(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.y, y: size.width - p.x)
        }

        let transform = (direction == .right) ? rotationRight : rotationLeft

        return Quadrilateral(
            topLeft: transform(topLeft),
            topRight: transform(topRight),
            bottomRight: transform(bottomRight),
            bottomLeft: transform(bottomLeft)
        )
    }
}
