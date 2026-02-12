import Foundation
import UIKit

struct ScanPreviewModel: Identifiable, Equatable, Hashable {
    let id = UUID()
    let documentType: DocumentTypeEnum
    var frames: [CapturedFrame]
}
