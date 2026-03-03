import UIKit

enum FilesGridItem: Identifiable, Equatable {
    case document(FileDocumentItem)
    case folder(FileFolderItem)
    
    var id: UUID {
        switch self {
        case .document(let doc):
            return doc.id
        case .folder(let folder):
            return folder.id
        }
    }
}

struct FileDocumentItem: Equatable {
    let id: UUID
    let folderID: UUID?
    let title: String
    let documentType: DocumentTypeEnum
    let createdAt: Date
    let pageCount: Int
    let isLocked: Bool
    let isFavourite: Bool
    let sizeInBytes: Int64
    let firstPagePath: String?
    let secondPagePath: String?
    var thumbnail: UIImage?
    var secondThumbnail: UIImage?
    var isSelected: Bool = false
}

struct FileFolderItem: Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let isLocked: Bool
    let documentsCount: Int
    var previewDocuments: [FileDocumentItem]
    var isSelected: Bool = false
}
