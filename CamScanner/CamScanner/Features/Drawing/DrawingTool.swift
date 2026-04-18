import UIKit

struct Stroke: Identifiable, Equatable {
    let id = UUID()

    var points: [CGPoint]

    var color: UIColor
    var opacity: CGFloat

    var widthN: CGFloat
}

enum DrawingTool: Equatable {
    case pen
    case eraser
}
