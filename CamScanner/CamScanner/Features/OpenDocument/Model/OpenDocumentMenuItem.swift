import Foundation

enum OpenDocumentMenuItem: Identifiable, CaseIterable, Equatable {
    case addToFavorites
    case removeFromFavorites
    case rename
    case lock
    case unlock
    case move
    case selectPages
    case reorderPages
    case delete

    var id: Self { self }

    var title: String {
        switch self {
        case .addToFavorites:
            return "Add to favorites"
        case .removeFromFavorites:
            return "Remove from favourite"
        case .rename:
            return "Rename"
        case .lock:
            return "Lock"
        case .unlock:
            return "Unlock"
        case .move:
            return "Move"
        case .selectPages:
            return "Select pages"
        case .reorderPages:
            return "Reorder pages"
        case .delete:
            return "Delete"
        }
    }
}
