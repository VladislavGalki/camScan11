import SwiftUI

public struct AnchoredLayout: Layout {
    private let location: CGPoint
    private let anchor: UnitPoint

    public init(location: CGPoint, anchor: UnitPoint) {
        self.location = location
        self.anchor = anchor
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let point = CGPoint(
            x: bounds.origin.x + location.x,
            y: bounds.origin.y + location.y
        )

        for subview in subviews {
            subview.place(
                at: point,
                anchor: anchor,
                proposal: proposal
            )
        }
    }
}
