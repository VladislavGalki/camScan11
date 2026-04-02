import Foundation

struct OpenDocumentSelectPagesMoveInputModel: Identifiable, Equatable {
    let id = UUID()
    let sourceDocumentID: UUID
    let sourceDocumentTitle: String
    let selectedRawPageIndices: [Int]
    let selectedItemsCount: Int
}

enum OpenDocumentSelectPagesMoveResult {
    case moved(Int)
    case movedAndClosedSource(Int)
    case failed
}

