import Foundation
import UIKit

struct SerializableStroke: Codable {
    let points: [SerializablePoint]
    let colorHex: String
    let opacity: CGFloat
    let widthN: CGFloat
}

struct SerializablePoint: Codable {
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Conversions

extension Stroke {
    func toSerializable() -> SerializableStroke {
        SerializableStroke(
            points: points.map { SerializablePoint(x: $0.x, y: $0.y) },
            colorHex: color.toRGBAHex(),
            opacity: opacity,
            widthN: widthN
        )
    }
}

extension SerializableStroke {
    func toStroke() -> Stroke {
        Stroke(
            points: points.map { CGPoint(x: $0.x, y: $0.y) },
            color: UIColor(rgbaHex: colorHex) ?? .black,
            opacity: opacity,
            widthN: widthN
        )
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    func toRGBAHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X%02X",
            Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255)
        )
    }
}
