import Foundation
import UIKit

struct CodableStroke: Codable {
    var points: [CodablePoint]
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat
    var widthN: CGFloat
    var opacity: CGFloat
}

enum StrokeCodec {
    static func encode(_ strokes: [Stroke]) -> Data? {
        let codable: [CodableStroke] = strokes.map {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            $0.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return CodableStroke(
                points: $0.points.map { CodablePoint($0) },
                r: r, g: g, b: b, a: a,
                widthN: $0.widthN,
                opacity: $0.opacity
            )
        }
        return try? JSONEncoder().encode(codable)
    }

    static func decode(_ data: Data) -> [Stroke] {
        guard let codable = try? JSONDecoder().decode([CodableStroke].self, from: data) else { return [] }
        return codable.map {
            Stroke(
                points: $0.points.map { $0.cgPoint },
                color: UIColor(red: $0.r, green: $0.g, blue: $0.b, alpha: $0.a),
                opacity: $0.opacity,
                widthN: $0.widthN
            )
        }
    }
}
