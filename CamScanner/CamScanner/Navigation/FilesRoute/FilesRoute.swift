import Foundation

enum FilesRoute: Route {
    case openFolder(FolderInputModel, onFolderDeleted: () -> Void)
    case openDocument(OpenDocumentInputModel)
}

extension FilesRoute: Equatable {
    static func == (lhs: FilesRoute, rhs: FilesRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.openFolder(lModel, _), .openFolder(rModel, _)):
            return lModel == rModel
        case let (.openDocument(lModel), .openDocument(rModel)):
            return lModel == rModel
        default :
            return false
        }
    }
}

extension FilesRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .openFolder(model, _):
            hasher.combine("openFolder")
            hasher.combine(model)
        case let .openDocument(model):
            hasher.combine("openDocument")
            hasher.combine(model)
        }
    }
}
