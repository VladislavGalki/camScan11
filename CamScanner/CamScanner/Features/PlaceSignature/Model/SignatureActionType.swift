import Foundation

enum SignatureActionType: String, CaseIterable, Identifiable {
    case edit
    case duplicate
    case delete

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
