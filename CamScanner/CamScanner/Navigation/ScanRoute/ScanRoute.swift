import Foundation

enum ScanRoute: Route {
    case scanPreview(
        ScanPreviewInputModel,
        onFinish: (ScanPreviewInputModel) -> Void
    )
}

extension ScanRoute: Equatable {
    static func == (lhs: ScanRoute, rhs: ScanRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.scanPreview(lModel, _), .scanPreview(rModel, _)):
            return lModel == rModel
        }
    }
}

extension ScanRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .scanPreview(model, _):
            hasher.combine("scanPreview")
            hasher.combine(model)
        }
    }
}
