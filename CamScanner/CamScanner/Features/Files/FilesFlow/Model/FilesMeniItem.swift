import Foundation

enum FilesMenuItem: CaseIterable, Identifiable {
    case share
    case rename
    case lock
    case unlockDocument
    case move
    case delete
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .share: return "Share"
        case .rename: return "Rename"
        case .lock: return "Lock"
        case .unlockDocument: return "Unlock"
        case .move: return "Move"
        case .delete: return "Delete"
        }
    }
}

enum FilesSelectableMenuItem {
    case move
    case share
    case merge
    case delete
}
