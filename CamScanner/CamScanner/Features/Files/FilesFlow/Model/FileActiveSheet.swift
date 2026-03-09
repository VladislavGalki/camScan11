import Foundation

enum FileActiveSheet: Identifiable {
    case createFolder
    case share(UUID)
    case multipleShare([UUID])
    case move(MoveDocumentInputModel)
    case rename
    
    var id: String {
        switch self {
        case .createFolder: return "CreateFolderSheet"
        case .share: return "ShareSheet"
        case .multipleShare: return "MultipleShareSheet"
        case .rename: return "RenameSheet"
        case .move: return "MoveSheet"
        }
    }
}
