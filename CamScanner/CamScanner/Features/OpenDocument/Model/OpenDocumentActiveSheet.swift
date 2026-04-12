import Foundation

enum OpenDocumentActiveSheet: Identifiable {
    case move(MoveDocumentInputModel)
    case reorderPages(ReorderPagesInputModel)

    var id: String {
        switch self {
        case .move:
            return "MoveSheet"
        case .reorderPages:
            return "ReorderPagesSheet"
        }
    }
}
