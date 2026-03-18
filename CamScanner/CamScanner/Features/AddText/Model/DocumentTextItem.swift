import Foundation
import CoreGraphics

struct DocumentTextItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let pageIndex: Int

    var text: String

    var centerX: CGFloat
    var centerY: CGFloat
    var width: CGFloat
    var height: CGFloat

    var rotation: CGFloat
    var style: DocumentTextStyle

    static func `default`(pageIndex: Int) -> DocumentTextItem {
        DocumentTextItem(
            id: UUID(),
            pageIndex: pageIndex,
            text: "Text",
            centerX: 0.5,
            centerY: 0.2,
            width: 0.22,
            height: 0.08,
            rotation: 0,
            style: .default
        )
    }
}


extension DocumentTextItem {
    init(entity: TextOverlayEntity) {
        self.id = entity.id
        self.pageIndex = Int(entity.pageIndex)
        self.text = entity.text
        self.centerX = entity.centerX
        self.centerY = entity.centerY
        self.width = entity.width
        self.height = entity.height
        self.rotation = entity.rotation
        self.style = DocumentTextStyle(
            fontSize: entity.fontSize,
            lineHeight: 28,
            letterSpacing: -0.43,
            textColorHex: entity.textColorHex,
            alignment: DocumentTextAlignment(rawValue: entity.alignmentRaw) ?? .left
        )
    }
}
