import Foundation

enum SignatureActionType: String, CaseIterable, Identifiable {
    case delete
    case duplicate
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .delete: return "Delete"
        case .duplicate: return "Duplicate"
        case .edit: return "Edit"
        }
    }

    var isDestructive: Bool {
        self == .delete
    }
}
