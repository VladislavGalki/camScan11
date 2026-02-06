import Foundation

struct ScanPreviewInputModel: Equatable, Hashable {
    let documentType: DocumentTypeEnum
    let pages: [DocumentTypeEnum : [CapturedFrame]]
}
