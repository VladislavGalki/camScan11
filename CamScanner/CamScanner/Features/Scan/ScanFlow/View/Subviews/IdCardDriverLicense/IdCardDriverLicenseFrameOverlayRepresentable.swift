import SwiftUI
import UIKit

struct IdCardDriverLicenseFrameOverlayRepresentable: UIViewRepresentable {
    let layout: IdFrameOverlayView.Layout
    let title: String
    let guideImage: UIImage?
    let shouldShowGrid: Bool
    let onRect: (CGRect) -> Void

    func makeUIView(context: Context) -> IdFrameOverlayView {
        let v = IdFrameOverlayView()
        v.layout = layout
        v.title = title
        v.guideImage = guideImage
        v.dimAlpha = 0.6
        v.showGrid = shouldShowGrid
        v.onFrameChanged = { rect in onRect(rect) }
        return v
    }

    func updateUIView(_ uiView: IdFrameOverlayView, context: Context) {
        uiView.layout = layout
        uiView.title = title
        uiView.guideImage = guideImage
        uiView.showGrid = shouldShowGrid
        uiView.setNeedsLayout()
    }
}
