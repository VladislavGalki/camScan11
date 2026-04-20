import SwiftUI
import UIKit

@MainActor
final class CreateSignatureViewModel: ObservableObject {
    @Published var strokes: [Stroke] = []
    @Published var currentPoints: [CGPoint] = []
    @Published var selectedColorHex: String = "#020202FF"
    @Published var brushSize: Double = 10.0

    private let documentRepository: DocumentRepository

    init(dependencies: AppDependencies) {
        self.documentRepository = dependencies.documentRepository
    }

    var selectedColor: Color {
        Color(rgbaHex: selectedColorHex) ?? .black
    }

    var isEmpty: Bool {
        strokes.isEmpty
    }

    func commitStroke(canvasSize: CGSize) {
        guard !currentPoints.isEmpty else { return }

        let minSide = max(1, min(canvasSize.width, canvasSize.height))
        let widthN = CGFloat(brushSize) / minSide

        let stroke = Stroke(
            points: currentPoints,
            color: UIColor(selectedColor),
            opacity: 1.0,
            widthN: max(0.001, widthN)
        )
        strokes.append(stroke)
        currentPoints = []
    }

    func selectColor(_ color: Color) {
        selectedColorHex = color.toRGBAHex() ?? "#020202FF"
    }

    func selectColorHex(_ hex: String) {
        selectedColorHex = hex
    }

    func eraseAll() {
        strokes = []
    }

    // MARK: - Save

    @discardableResult
    func saveSignature(canvasSize: CGSize) throws -> UUID? {
        guard let image = renderSignatureImage(canvasSize: canvasSize) else { return nil }

        let serializableStrokes = strokes.map { $0.toSerializable() }
        let strokeData = try? JSONEncoder().encode(serializableStrokes)

        return try documentRepository.saveSignature(
            image: image,
            strokeData: strokeData,
            colorHex: selectedColorHex,
            brushSize: brushSize
        )
    }

    // MARK: - Render

    private func renderSignatureImage(canvasSize: CGSize) -> UIImage? {
        guard !strokes.isEmpty else { return nil }

        let minSide = max(1, min(canvasSize.width, canvasSize.height))

        // Compute bounding box of all strokes in canvas coordinates
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for stroke in strokes {
            let widthPx = stroke.widthN * minSide
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

        let renderSize = CGSize(width: cropWidth, height: cropHeight)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            for stroke in strokes {
                let widthPx = stroke.widthN * minSide
                let color = stroke.color.withAlphaComponent(stroke.opacity)

                cgCtx.setStrokeColor(color.cgColor)
                cgCtx.setLineWidth(widthPx)
                cgCtx.setLineCap(.round)
                cgCtx.setLineJoin(.round)

                guard !stroke.points.isEmpty else { continue }

                let p0 = CGPoint(
                    x: stroke.points[0].x * canvasSize.width - minX,
                    y: stroke.points[0].y * canvasSize.height - minY
                )

                if stroke.points.count == 1 {
                    let r = max(1, widthPx / 2)
                    cgCtx.setFillColor(color.cgColor)
                    cgCtx.fillEllipse(in: CGRect(x: p0.x - r, y: p0.y - r, width: 2 * r, height: 2 * r))
                } else {
                    cgCtx.beginPath()
                    cgCtx.move(to: p0)
                    for pN in stroke.points.dropFirst() {
                        let p = CGPoint(
                            x: pN.x * canvasSize.width - minX,
                            y: pN.y * canvasSize.height - minY
                        )
                        cgCtx.addLine(to: p)
                    }
                    cgCtx.strokePath()
                }
            }
        }
    }
}
