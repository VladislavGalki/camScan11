import UIKit

enum FilesItemType {
    case document
    case folder
}

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

struct FileDocumentItem: Equatable, Hashable {
    let id: UUID
    let folderID: UUID?
    let title: String
    let documentType: DocumentTypeEnum
    let createdAt: Date
    let pageCount: Int
    let isLocked: Bool
    var lockViaFaceId: Bool = false
    let isFavourite: Bool
    let sizeInBytes: Int64
    let firstPagePath: String?
    let secondPagePath: String?
    var thumbnail: UIImage?
    var secondThumbnail: UIImage?
    var isSelected: Bool = false
    var passwordHash: Data?
    var passwordSalt: Data?
}

struct FileFolderItem: Equatable, Hashable {
    let id: UUID
    let title: String
    let createdAt: Date
    var isLocked: Bool
    var lockViaFaceId: Bool = false
    let documentsCount: Int
    var previewDocuments: [FileDocumentItem]
    var isSelected: Bool = false
    var isHighlighted: Bool = false
    var passwordHash: Data?
    var passwordSalt: Data?
}

extension FilesGridItem {
    var title: String {
        switch self {
        case .document(let doc):
            return doc.title
        case .folder(let folder):
            return folder.title
        }
    }

    var itemType: FilesItemType {
        switch self {
        case .document:
            return .document
        case .folder:
            return .folder
        }
    }

    var isLocked: Bool {
        switch self {
        case .document(let doc):
            return doc.isLocked
        case .folder(let folder):
            return folder.isLocked
        }
    }

    var isFaceIDEnabled: Bool {
        switch self {
        case .document(let doc):
            return doc.lockViaFaceId
        case .folder(let folder):
            return folder.lockViaFaceId
        }
    }

    var passwordData: (salt: Data, hash: Data)? {
        switch self {
        case .document(let doc):
            guard let salt = doc.passwordSalt,  let hash = doc.passwordHash else { return nil }
            return (salt, hash)
        case .folder(let folder):
            guard let salt = folder.passwordSalt, let hash = folder.passwordHash else { return nil }
            return (salt, hash)
        }
    }

    var folder: FileFolderItem? {
        if case .folder(let folder) = self {
            return folder
        }
        
        return nil
    }

    var document: FileDocumentItem? {
        if case .document(let doc) = self {
            return doc
        }
        
        return nil
    }
}
