import Foundation
import UIKit

struct ScanPreviewModel: Identifiable, Equatable {
    let id = UUID()
    let documentType: DocumentTypeEnum
    var frames: [CapturedFrame]
}
