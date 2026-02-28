import Foundation

enum ScanRoute: Route {
    case scanPreview(
        ScanPreviewInputModel,
        onFinish: (ScanPreviewInputModel) -> Void,
        onSuccessFlow: () -> Void
    )
    
    case scanCropper(
        ScanCropperInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )
    
    case share(ShareInputModel)
}

extension ScanRoute: Equatable {
    static func == (lhs: ScanRoute, rhs: ScanRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanPreview(lModel, _, _), .scanPreview(rModel, _, _)):
            return lModel == rModel
        case let (.scanCropper(lModel, _), .scanCropper(rModel, _)):
            return lModel == rModel
        case let (.share(lModel), .share(rModel)):
            return lModel == rModel
        default:
            return false
        }
    }
}

extension ScanRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .scanPreview(model, _, _):
            hasher.combine("scanPreview")
            hasher.combine(model)
        case let .scanCropper(model, _):
            hasher.combine("scanCropper")
            hasher.combine(model)
        case let .share(model):
            hasher.combine("share")
            hasher.combine(model)
        }
    }
}
