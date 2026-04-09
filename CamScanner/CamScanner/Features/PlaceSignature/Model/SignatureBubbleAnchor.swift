import Foundation
import CoreGraphics

struct SignatureBubbleAnchor: Equatable {
    let signatureID: UUID
    let pageIndex: Int
    let rect: CGRect
}
