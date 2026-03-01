import UIKit
import Foundation

enum RecentDocuments {
    case preview
    case documents(RecentDocumentModel)
}

struct RecentDocumentModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let documentType: DocumentTypeEnum
    var thumbnail: UIImage?
    var secondThumbnail: UIImage?
    let firstPageImagePath: String?
    let secondPageImagePath: String?
    let pageCountText: String
    let isLocked: Bool
    let createdAt: Date
}
