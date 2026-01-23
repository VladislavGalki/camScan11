import SwiftUI

struct BorderModifier: ViewModifier {
    let color: Color
    let width: CGFloat
    let radius: CGFloat
    let corners: UIRectCorner

    func body(content: Content) -> some View {
        content
            .overlay(
                CornerRadiusShape(
                    radius: radius,
                    corners: corners
                )
                .strokeBorder(color, lineWidth: width)
            )
    }
}

public extension View {
    func appBorderModifier(
        _ color: Color,
        width: CGFloat = 1,
        radius: CGFloat,
        corners: UIRectCorner = .allCorners
    ) -> some View {
        modifier(
            BorderModifier(
                color: color,
                width: width,
                radius: radius,
                corners: corners
            )
        )
    }
}
