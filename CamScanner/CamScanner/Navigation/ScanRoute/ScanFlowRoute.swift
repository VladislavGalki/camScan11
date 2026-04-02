import Foundation

enum ScanFlowRoute: Route {
    case scan
    case importCropper(ScanCropperInputModel)
}

extension ScanFlowRoute: Equatable {
    static func == (lhs: ScanFlowRoute, rhs: ScanFlowRoute) -> Bool {
        switch (lhs, rhs) {
        case (.scan, .scan):
            return true
        case let (.importCropper(lModel), .importCropper(rModel)):
            return lModel == rModel
        default:
            return false
        }
    }
}

extension ScanFlowRoute: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .scan:
            hasher.combine("scan")
        case let .importCropper(model):
            hasher.combine("importCropper")
            hasher.combine(model)
        }
    }
}
