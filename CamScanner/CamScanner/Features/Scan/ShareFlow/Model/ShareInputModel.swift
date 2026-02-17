import Foundation

struct ShareInputModel: Equatable, Hashable {
    let documentType: DocumentTypeEnum
    let pages: [ScanPreviewModel]
}
