import Foundation

enum OpenDocumentRoute: Route {
    case scanCropper(
        ScanCropperInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )
    
    case share(ShareInputModel)
}

extension OpenDocumentRoute: Equatable {
    static func == (lhs: OpenDocumentRoute, rhs: OpenDocumentRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanCropper(lModel, _), .scanCropper(rModel, _)):
            return lModel == rModel
        case let (.share(lModel), .share(rModel)):
            return lModel == rModel
        default:
            return false
        }
    }
}

extension OpenDocumentRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .scanCropper(model, _):
            hasher.combine("scanCropper")
            hasher.combine(model)
        case let .share(model):
            hasher.combine("share")
            hasher.combine(model)
        }
    }
}
