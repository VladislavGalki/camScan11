import SwiftUI
import UIKit

struct IdFrameOverlayRepresentable: UIViewRepresentable {

    let layout: IdFrameOverlayView.Layout
    let cornerRadius: CGFloat
    let title: String
    let onRect: (CGRect) -> Void

    func makeUIView(context: Context) -> IdFrameOverlayView {
        let v = IdFrameOverlayView()
        v.layout = layout
        v.cornerRadius = cornerRadius
        v.title = title
        v.dimAlpha = 0.55
        v.onFrameChanged = { rect in onRect(rect) }
        return v
    }

    func updateUIView(_ uiView: IdFrameOverlayView, context: Context) {
        uiView.layout = layout
        uiView.cornerRadius = cornerRadius
        uiView.title = title
        uiView.setNeedsLayout()
    }
}
