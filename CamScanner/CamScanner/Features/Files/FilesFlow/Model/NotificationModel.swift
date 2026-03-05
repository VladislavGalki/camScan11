import Foundation

enum NotificationModel {
    case folderCreated
    case folderRemoved
    case fileRemoved
    case pinCreated
    case pinRemoved
    
    var title: String {
        switch self {
        case .folderCreated:
            return "Folder created"
        case .folderRemoved:
            return "Folder was deleted"
        case .fileRemoved:
            return "File was deleted"
        case .pinCreated:
            return "PIN created"
        case .pinRemoved:
            return "PIN removed"
        }
    }
}
