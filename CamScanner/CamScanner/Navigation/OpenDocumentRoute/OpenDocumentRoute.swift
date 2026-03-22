import Foundation

enum OpenDocumentRoute: Route {
    case scanCropper(
        ScanCropperInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )

    case addText(AddTextInputModel)

    case share(ShareInputModel)

    case scanFlow(ScanInputModel, onDismiss: () -> Void)
}

extension OpenDocumentRoute: Equatable {
    static func == (lhs: OpenDocumentRoute, rhs: OpenDocumentRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanCropper(lModel, _), .scanCropper(rModel, _)):
            return lModel == rModel
        case let (.addText(lModel), .addText(rModel)):
            return lModel == rModel
        case let (.share(lModel), .share(rModel)):
            return lModel == rModel
        case (.scanFlow, .scanFlow):
            return true
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
        case let .addText(model):
            hasher.combine("addText")
            hasher.combine(model)
        case let .share(model):
            hasher.combine("share")
            hasher.combine(model)
        case .scanFlow:
            hasher.combine("scanFlow")
        }
    }
}
