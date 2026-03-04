import Foundation

enum FilesViewMode: CaseIterable, Identifiable {
    case grid
    case list
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }
}
