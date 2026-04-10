import Foundation
import UIKit

struct DocumentSignatureItem: Identifiable {
    let id: UUID
    let pageIndex: Int
    let signatureEntityID: UUID
    var centerX: CGFloat
    var centerY: CGFloat
    var width: CGFloat
    var height: CGFloat
    var rotation: CGFloat
    var colorHex: String
    var thickness: CGFloat
    var opacity: CGFloat
    var image: UIImage?
    let aspectRatio: CGFloat
    var strokes: [Stroke]?
}

// MARK: - Equatable (exclude image and strokes)

extension DocumentSignatureItem: Equatable {
    static func == (lhs: DocumentSignatureItem, rhs: DocumentSignatureItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.pageIndex == rhs.pageIndex &&
        lhs.signatureEntityID == rhs.signatureEntityID &&
        lhs.centerX == rhs.centerX &&
        lhs.centerY == rhs.centerY &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.rotation == rhs.rotation &&
        lhs.colorHex == rhs.colorHex &&
        lhs.thickness == rhs.thickness &&
        lhs.opacity == rhs.opacity &&
        lhs.aspectRatio == rhs.aspectRatio
    }
}

// MARK: - Hashable (exclude image and strokes)

extension DocumentSignatureItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(pageIndex)
        hasher.combine(signatureEntityID)
        hasher.combine(centerX)
        hasher.combine(centerY)
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(rotation)
    }
}
