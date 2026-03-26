import Foundation
import CoreGraphics

struct DocumentWatermarkItem: Identifiable, Equatable, Hashable {
    let id: UUID
    let pageIndex: Int

    var text: String

    var centerX: CGFloat
    var centerY: CGFloat
    var width: CGFloat
    var height: CGFloat

    var rotation: CGFloat
    var opacity: CGFloat
    var style: DocumentWatermarkStyle

    static func `default`(pageIndex: Int) -> DocumentWatermarkItem {
        DocumentWatermarkItem(
            id: UUID(),
            pageIndex: pageIndex,
            text: "Watermark",
            centerX: 0.5,
            centerY: 0.5,
            width: 0.35,
            height: 0.08,
            rotation: 0,
            opacity: 1.0,
            style: .default
        )
    }
}

extension DocumentWatermarkItem {
    init(entity: WatermarkOverlayEntity) {
        self.id = entity.id
        self.pageIndex = Int(entity.pageIndex)
        self.text = entity.text
        self.centerX = entity.centerX
        self.centerY = entity.centerY
        self.width = entity.width
        self.height = entity.height
        self.rotation = entity.rotation
        self.opacity = entity.opacity
        self.style = DocumentWatermarkStyle(
            fontSize: entity.fontSize,
            lineHeight: 28,
            letterSpacing: -0.43,
            textColorHex: entity.textColorHex,
            alignment: DocumentTextAlignment(rawValue: entity.alignmentRaw) ?? .left
        )
    }
}
