import Foundation

enum FileActiveSheet: Identifiable {
    case createFolder
    case share(UUID)
    case rename
    
    var id: String {
        switch self {
        case .createFolder: return "CreateFolderSheet"
        case .share: return "ShareSheet"
        case .rename: return "RenameSheet"
        }
    }
}
