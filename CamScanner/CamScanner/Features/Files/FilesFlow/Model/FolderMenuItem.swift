import Foundation

enum FilesFolderMenuItem: CaseIterable, Identifiable {
    case rename
    case lock
    case unlockDocument
    case delete
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .rename: return "Rename"
        case .lock: return "Lock"
        case .unlockDocument: return "Unlock"
        case .delete: return "Delete"
        }
    }
}
