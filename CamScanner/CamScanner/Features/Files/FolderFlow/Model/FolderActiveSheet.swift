import Foundation

enum FolderActiveSheet: Identifiable {
    case share
    case rename(String)
    case move
    
    var id: String {
        switch self {
        case .share: return "ShareSheet"
        case .rename: return "RenameSheet"
        case .move: return "MoveSheet"
        }
    }
}
