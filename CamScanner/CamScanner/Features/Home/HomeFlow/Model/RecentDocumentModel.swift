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
    let previewDocumentType: DocumentTypeEnum
    let isMerged: Bool

    var thumbnail: UIImage?
    var secondThumbnail: UIImage?

    let firstPageImagePath: String?
    let secondPageImagePath: String?

    let pageCountText: String
    let isFavorite: Bool
    let isLocked: Bool
    let lockViaFaceId: Bool
    let createdAt: Date
    let lastViewedAt: Date
}
