import SwiftUI

struct AddTextStyleDraft: Equatable {
    var colorHex: String
    var fontSize: CGFloat
    var rotation: CGFloat

    static let `default` = AddTextStyleDraft(
        colorHex: "#020202FF",
        fontSize: 22,
        rotation: 0
    )
}
