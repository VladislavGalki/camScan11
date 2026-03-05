import Foundation
import Vision

extension Array where Element == Quadrilateral {
    func biggest() -> Quadrilateral? {
        let biggestRectangle = self.max(by: { rect1, rect2 -> Bool in
            return rect1.perimeter < rect2.perimeter
        })

        return biggestRectangle
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
