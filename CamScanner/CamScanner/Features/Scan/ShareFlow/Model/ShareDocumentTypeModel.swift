import Foundation

struct ShareDocumentTypeModel: Identifiable, Equatable  {
    let id = UUID()
    let type: DocumentType
    let image: AppIcon
    var isSelected: Bool = false
}

extension ShareDocumentTypeModel {
    enum DocumentType {
        case pdf, jpg, doc, txt, xls, ppt
    }
}

