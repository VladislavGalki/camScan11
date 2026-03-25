import Foundation
import CoreGraphics

struct DocumentWatermarkStyle: Equatable, Hashable, Codable {
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var letterSpacing: CGFloat
    var textColorHex: String
    var alignment: DocumentTextAlignment

    static let `default` = DocumentWatermarkStyle(
        fontSize: 22,
        lineHeight: 28,
        letterSpacing: -0.43,
        textColorHex: "#020202FF",
        alignment: .left
    )
}
