import UIKit

struct Stroke: Identifiable, Equatable {
    let id = UUID()

    /// ✅ normalized точки в координатах изображения (0...1)
    var points: [CGPoint]

    /// ✅ цвет + opacity
    var color: UIColor
    var opacity: CGFloat

    /// ✅ normalized ширина относительно minSide изображения (0...1)
    var widthN: CGFloat

    // быстрый хиттест (в normalized не делаем — делаем в view-space)
}

enum DrawingTool: Equatable {
    case pen
    case eraser
}
