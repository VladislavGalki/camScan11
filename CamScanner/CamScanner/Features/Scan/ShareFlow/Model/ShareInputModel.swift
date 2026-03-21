import Foundation

struct ShareInputModel: Equatable, Hashable {
    let documentName: String
    let documentType: DocumentTypeEnum
    let pages: [ScanPreviewModel]
    var textItems: [DocumentTextItem] = []
    var cellHeight: CGFloat = 0
}
