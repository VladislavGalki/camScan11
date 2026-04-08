import SwiftUI

@MainActor
final class CreateSignatureViewModel: ObservableObject {
    @Published var strokes: [Stroke] = []
    @Published var currentPoints: [CGPoint] = []
    @Published var selectedColorHex: String = "#020202FF"
    @Published var brushSize: Double = 10.0

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
}
