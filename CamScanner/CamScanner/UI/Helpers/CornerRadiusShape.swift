import SwiftUI

public struct CornerRadiusShape: InsettableShape {
    let radius: CGFloat
    let corners: UIRectCorner
    var insetAmount: CGFloat = 0

    public func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)

        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: max(0, radius - insetAmount),
                height: max(0, radius - insetAmount)
            )
        )

        return Path(path.cgPath)
    }
}

// MARK: - View extension

public extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        return clipShape(CornerRadiusShape(
            radius: radius,
            corners: corners
        ))
    }
}
