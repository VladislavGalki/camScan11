import UIKit
import Foundation

enum RecentDocuments {
    case preview
    case documents(RecentDocumentModel)
}

struct RecentDocumentModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let kind: Kind              // scan/id
    let idType: String?       // для kind - id
    var thumbnail: UIImage?
    var secondThumbnail: UIImage?
    let firstPageImagePath: String?
    let secondPageImagePath: String?
    let pageCount: String
    let isLocked: Bool
    let createdAt: Date
    let rememberedFilter: String?
    
    enum Kind {
        case scan
        case id
        
        init(_ kind: String) {
            switch kind {
            case "scan":
                self = .scan
            case "id":
                self = .id
            default:
                self = .scan
            }
        }
        
        var title: String {
            switch self {
            case .scan:
                return "Document"
            case .id:
                return "ID Card"
            }
        }
    }
}
