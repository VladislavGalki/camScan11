import Foundation
import CoreGraphics

struct CodablePoint: Codable {
    var x: CGFloat
    var y: CGFloat
    init(_ p: CGPoint) { x = p.x; y = p.y }
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct CodableQuad: Codable {
    var topLeft: CodablePoint
    var topRight: CodablePoint
    var bottomRight: CodablePoint
    var bottomLeft: CodablePoint

    init(_ q: Quadrilateral) {
        topLeft = .init(q.topLeft)
        topRight = .init(q.topRight)
        bottomRight = .init(q.bottomRight)
        bottomLeft = .init(q.bottomLeft)
    }

    func toQuad() -> Quadrilateral {
        Quadrilateral(
            topLeft: topLeft.cgPoint,
            topRight: topRight.cgPoint,
            bottomRight: bottomRight.cgPoint,
            bottomLeft: bottomLeft.cgPoint
        )
    }
}

enum QuadCodec {
    static func encode(_ q: Quadrilateral) -> Data? {
        try? JSONEncoder().encode(CodableQuad(q))
    }

    static func decode(_ data: Data) -> Quadrilateral? {
        guard let decoded = try? JSONDecoder().decode(CodableQuad.self, from: data) else { return nil }
        return decoded.toQuad()
    }
}
