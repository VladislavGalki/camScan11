import Foundation

enum OpenDocumentMenuItem: Identifiable, CaseIterable, Equatable {
    case rename
    case lock
    case unlock
    case delete

    var id: Self { self }

    var title: String {
        switch self {
        case .rename:
            return "Rename"
        case .lock:
            return "Lock"
        case .unlock:
            return "Unlock"
        case .delete:
            return "Delete"
        }
    }
}
