import Foundation

enum ShareActiveSheet: Identifiable {
    case renameFileSheet
    case exportShareSheet
    case setPasswordSheet
    
    var id: String {
        switch self {
        case .renameFileSheet: return "RenameFileSheet"
        case .exportShareSheet: return "ExportShareSheet"
        case .setPasswordSheet: return "SetPasswordSheet"
        }
    }
}
