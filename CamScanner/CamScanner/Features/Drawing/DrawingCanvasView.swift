import SwiftUI
import UIKit

struct DrawingCanvasView: UIViewRepresentable {

    @Binding var strokes: [Stroke]

    let tool: DrawingTool
    let color: UIColor
    let alpha: CGFloat
    let width: CGFloat

    let canvasSize: CGSize
    let imageSize: CGSize

    func makeUIView(context: Context) -> DrawingCanvasUIView {
        let v = DrawingCanvasUIView()
        v.onStrokesChanged = { new in
            DispatchQueue.main.async {
                self.strokes = new
            }
        }
        return v
    }

    func updateUIView(_ uiView: DrawingCanvasUIView, context: Context) {
        uiView.tool = tool
        uiView.penColor = color
        uiView.penAlpha = alpha
        uiView.penWidth = width

        uiView.setStrokes(strokes)
    }

    func mapStrokesToImageSpace(_ strokes: [Stroke]) -> [Stroke] {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return strokes }

        let fit = aspectFitRect(imageSize: imageSize, in: CGRect(origin: .zero, size: canvasSize))

        let sx = fit.width / imageSize.width
        let sy = fit.height / imageSize.height
        let scale = min(sx, sy)

        let ox = fit.minX
        let oy = fit.minY

        func toImage(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: (p.x - ox) / scale,
                y: (p.y - oy) / scale
            )
        }

        return strokes.map { s in
            var copy = s
            copy.points = s.points.map(toImage)
            copy.widthN = s.widthN / scale
            return copy
        }
    }

    private func aspectFitRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        let iw = max(1, imageSize.width)
        let ih = max(1, imageSize.height)
        let rw = rect.width
        let rh = rect.height
        let scale = min(rw / iw, rh / ih)
        let w = iw * scale
        let h = ih * scale
        return CGRect(x: rect.midX - w/2, y: rect.midY - h/2, width: w, height: h)
    }
}
