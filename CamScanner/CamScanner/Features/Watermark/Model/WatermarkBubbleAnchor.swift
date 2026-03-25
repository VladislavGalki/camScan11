import Foundation
import CoreGraphics

struct WatermarkBubbleAnchor: Equatable {
    let watermarkID: UUID
    let pageIndex: Int
    let rect: CGRect
}
