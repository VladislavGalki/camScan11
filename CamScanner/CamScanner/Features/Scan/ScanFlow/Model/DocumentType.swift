import Foundation

enum DocumentTypeEnum: String {
    case scan
    case id
}

struct DocumentType: Identifiable, Hashable {
    let id: UUID = UUID()
    let type: DocumentTypeEnum
    let title: String
    var isSelected: Bool
}
