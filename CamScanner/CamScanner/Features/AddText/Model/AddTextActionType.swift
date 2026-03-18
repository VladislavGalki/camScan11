import Foundation

enum AddTextActionType: String, CaseIterable, Identifiable {
    case edit
    case style
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: return "Edit text"
        case .style: return "Adjust style"
        case .delete: return "Delete"
        }
    }

    var isDestructive: Bool {
        self == .delete
    }
}
