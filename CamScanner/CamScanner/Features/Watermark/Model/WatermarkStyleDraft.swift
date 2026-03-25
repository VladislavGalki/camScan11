import SwiftUI

struct WatermarkStyleDraft: Equatable {
    var colorHex: String
    var fontSize: CGFloat
    var rotation: CGFloat
    var opacity: CGFloat

    static let `default` = WatermarkStyleDraft(
        colorHex: "#020202FF",
        fontSize: 22,
        rotation: 0,
        opacity: 0.3
    )
}
