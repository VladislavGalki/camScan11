import Foundation

enum OpenDocumentRoute: Route {
    case scanCropper(
        ScanCropperInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )

    case addText(AddTextInputModel)

    case watermark(WatermarkInputModel)

    case erase(EraseInputModel)

    case share(ShareInputModel)

    case scanFlow(ScanInputModel, onDismiss: () -> Void)

    case selectPages(OpenDocumentSelectPagesInputModel)

    case createSignature(onSaved: ((UUID) -> Void)? = nil)

    case placeSignature(PlaceSignatureInputModel)
}

extension OpenDocumentRoute: Equatable {
    static func == (lhs: OpenDocumentRoute, rhs: OpenDocumentRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanCropper(lModel, _), .scanCropper(rModel, _)):
            return lModel == rModel
        case let (.addText(lModel), .addText(rModel)):
            return lModel == rModel
        case let (.watermark(lModel), .watermark(rModel)):
            return lModel == rModel
        case let (.erase(lModel), .erase(rModel)):
            return lModel == rModel
        case let (.share(lModel), .share(rModel)):
            return lModel == rModel
        case (.scanFlow, .scanFlow):
            return true
        case let (.selectPages(lModel), .selectPages(rModel)):
            return lModel == rModel
        case (.createSignature, .createSignature):
            return true
        case let (.placeSignature(lModel), .placeSignature(rModel)):
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
        case let .addText(model):
            hasher.combine("addText")
            hasher.combine(model)
        case let .watermark(model):
            hasher.combine("watermark")
            hasher.combine(model)
        case let .erase(model):
            hasher.combine("erase")
            hasher.combine(model)
        case let .share(model):
            hasher.combine("share")
            hasher.combine(model)
        case .scanFlow:
            hasher.combine("scanFlow")
        case let .selectPages(model):
            hasher.combine("selectPages")
            hasher.combine(model)
        case .createSignature:
            hasher.combine("createSignature")
        case let .placeSignature(model):
            hasher.combine("placeSignature")
            hasher.combine(model)
        }
    }
}
