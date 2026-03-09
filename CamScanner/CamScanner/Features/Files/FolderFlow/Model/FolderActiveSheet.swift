import Foundation

enum FolderActiveSheet: Identifiable {
    case share(UUID)
    case rename(String)
    case move(MoveDocumentInputModel)
    
    var id: String {
        switch self {
        case .share: return "ShareSheet"
        case .rename: return "RenameSheet"
        case .move: return "MoveSheet"
        }
    }
}
