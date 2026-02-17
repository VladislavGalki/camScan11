import Foundation

struct ShareInputModel: Equatable {
    let documentType: DocumentTypeEnum
    let pages: [DocumentTypeEnum : [CapturedFrame]]
}
