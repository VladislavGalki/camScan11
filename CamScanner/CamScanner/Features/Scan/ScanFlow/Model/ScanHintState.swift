import Foundation

enum ScanHintState: Equatable {
    case none
    case placeDocument
    case holdSteady

    var text: String {
        switch self {
        case .none:
            return ""
        case .placeDocument:
            return "Place a document"
        case .holdSteady:
            return "Hold steady"
        }
    }
}
