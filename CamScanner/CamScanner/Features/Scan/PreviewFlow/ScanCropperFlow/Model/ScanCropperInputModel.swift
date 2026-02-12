import Foundation

struct ScanCropperInputModel: Equatable, Hashable {
    let pages: [ScanPreviewModel]
    let documentType: DocumentTypeEnum
}
