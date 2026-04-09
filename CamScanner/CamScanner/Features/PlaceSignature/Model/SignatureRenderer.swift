import UIKit

enum SignatureRenderer {
    /// Re-renders strokes on a fixed-size canvas matching the original image dimensions.
    /// This avoids bounding-box recalculation which changes proportions when brush size differs.
    static func render(
        strokes: [Stroke],
        colorOverride: UIColor,
        brushSizeOverride: CGFloat,
        originalImageSize: CGSize
    ) -> UIImage? {
        guard !strokes.isEmpty, originalImageSize.width > 0, originalImageSize.height > 0 else { return nil }

        // Use a reference canvas to convert normalized stroke coordinates.
        // We choose a square canvas so that widthN (normalized to minSide) stays consistent.
        let canvasSide: CGFloat = 400
        let canvasSize = CGSize(width: canvasSide, height: canvasSide)
        let minSide = canvasSide
        let widthPx = brushSizeOverride

        // Step 1: Compute bounding box using the SAME logic as CreateSignatureViewModel
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for stroke in strokes {
            let halfW = widthPx / 2
            for pN in stroke.points {
                let x = pN.x * canvasSize.width
                let y = pN.y * canvasSize.height
                minX = min(minX, x - halfW)
                minY = min(minY, y - halfW)
                maxX = max(maxX, x + halfW)
                maxY = max(maxY, y + halfW)
            }
        }

        let padding: CGFloat = 8
        minX = max(0, minX - padding)
        minY = max(0, minY - padding)
        maxX = min(canvasSize.width, maxX + padding)
        maxY = min(canvasSize.height, maxY + padding)

        let cropWidth = maxX - minX
        let cropHeight = maxY - minY
        guard cropWidth > 0, cropHeight > 0 else { return nil }

        // Step 2: Render at the ORIGINAL image's pixel dimensions.
        // Scale strokes from the cropped region to fill the original image size.
        let scaleX = originalImageSize.width / cropWidth
        let scaleY = originalImageSize.height / cropHeight

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1 // originalImageSize already accounts for desired resolution

        let renderer = UIGraphicsImageRenderer(size: originalImageSize, format: format)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            for stroke in strokes {
                let color = colorOverride.withAlphaComponent(stroke.opacity)

                cgCtx.setStrokeColor(color.cgColor)
                cgCtx.setLineWidth(widthPx * min(scaleX, scaleY))
                cgCtx.setLineCap(.round)
                cgCtx.setLineJoin(.round)

                guard !stroke.points.isEmpty else { continue }

                let p0 = CGPoint(
                    x: (stroke.points[0].x * canvasSize.width - minX) * scaleX,
                    y: (stroke.points[0].y * canvasSize.height - minY) * scaleY
                )

                if stroke.points.count == 1 {
                    let r = max(1, widthPx * min(scaleX, scaleY) / 2)
                    cgCtx.setFillColor(color.cgColor)
                    cgCtx.fillEllipse(in: CGRect(x: p0.x - r, y: p0.y - r, width: 2 * r, height: 2 * r))
                } else {
                    cgCtx.beginPath()
                    cgCtx.move(to: p0)
                    for pN in stroke.points.dropFirst() {
                        let p = CGPoint(
                            x: (pN.x * canvasSize.width - minX) * scaleX,
                            y: (pN.y * canvasSize.height - minY) * scaleY
                        )
                        cgCtx.addLine(to: p)
                    }
                    cgCtx.strokePath()
                }
            }
        }
    }
}
