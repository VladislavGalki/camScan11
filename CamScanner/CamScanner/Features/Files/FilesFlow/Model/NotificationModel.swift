import Foundation

enum NotificationModel {
    case folderCreated
    case pinCreated
    
    var title: String {
        switch self {
        case .folderCreated:
            return "Folder created"
        case .pinCreated:
            return "PIN created"
        }
    }
}
