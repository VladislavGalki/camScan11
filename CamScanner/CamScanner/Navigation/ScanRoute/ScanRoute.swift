import Foundation

enum ScanRoute: Route {
    case scanPreview(
        ScanPreviewInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )
    
    case scanCropper(
        ScanCropperInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )
    
    case share
}

extension ScanRoute: Equatable {
    static func == (lhs: ScanRoute, rhs: ScanRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanPreview(lModel, _), .scanPreview(rModel, _)):
            return lModel == rModel
        case let (.scanCropper(lModel, _), .scanCropper(rModel, _)):
            return lModel == rModel
        case (.share, .share):
            return true
        default:
            return false
        }
    }
}

extension ScanRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .scanPreview(model, _):
            hasher.combine("scanPreview")
            hasher.combine(model)
        case let .scanCropper(model, _):
            hasher.combine("scanCropper")
            hasher.combine(model)
        case .share:
            hasher.combine("share")
        }
    }
}
