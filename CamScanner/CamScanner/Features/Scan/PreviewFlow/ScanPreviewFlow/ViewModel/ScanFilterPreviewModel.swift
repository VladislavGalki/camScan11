import Foundation
import UIKit

struct ScanFilterPreviewModel: Identifiable, Equatable {
    let id: DocumentFilterType
    let filter: DocumentFilterType
    var previewImage: UIImage?
    var isSelected: Bool
    var isEnabled: Bool
}
