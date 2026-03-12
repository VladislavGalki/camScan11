import Foundation

struct CropperPageItem: Identifiable, Equatable {
    let id: UUID
    let documentType: DocumentTypeEnum
    var frame: CapturedFrame
}
