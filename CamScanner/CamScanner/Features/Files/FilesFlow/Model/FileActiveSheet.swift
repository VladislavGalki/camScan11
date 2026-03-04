import Foundation

enum FileActiveSheet: Identifiable {
    case createFolder
    case rename
    
    var id: String {
        switch self {
        case .createFolder: return "CreateFolderSheet"
        case .rename: return "RenameSheet"
        }
    }
}
