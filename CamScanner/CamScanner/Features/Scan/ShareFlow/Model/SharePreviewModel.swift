import Foundation
import UIKit

struct SharePreviewModel: Identifiable, Equatable, Hashable {
    let id = UUID()
    let documentType: DocumentTypeEnum
    var frames: [CapturedFrame]
    var textItems: [DocumentTextItem] = []
    var cellHeight: CGFloat = 0
    var isSelected: Bool = false
}
