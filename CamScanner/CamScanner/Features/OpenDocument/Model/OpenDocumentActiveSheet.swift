import Foundation

enum OpenDocumentActiveSheet: Identifiable {
    case move(MoveDocumentInputModel)

    var id: String {
        switch self {
        case .move:
            return "MoveSheet"
        }
    }
}
