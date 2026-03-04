import Foundation

enum FilesSortType: CaseIterable, Identifiable {
    case recent
    case starred
    case locked
    case dateCreated
    case size
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .recent: return "Recent"
        case .starred: return "Starred"
        case .locked: return "Locked"
        case .dateCreated: return "Date created"
        case .size: return "Size"
        }
    }
    
    var sortType: String {
        switch self {
        case .recent:
            return "lastViewed"
        case .starred:
            return "isFavourite"
        case .locked:
            return "isLocked"
        case .dateCreated:
            return "createdAt"
        case .size:
            return "cachedSize"
        }
    }
}
