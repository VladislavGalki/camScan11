import Foundation

enum FilesMenuItem: CaseIterable, Identifiable {
    case share
    case rename
    case lock
    case move
    case delete
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .share: return "Share"
        case .rename: return "Rename"
        case .lock: return "Lock"
        case .move: return "Move"
        case .delete: return "Delete"
        }
    }
}
