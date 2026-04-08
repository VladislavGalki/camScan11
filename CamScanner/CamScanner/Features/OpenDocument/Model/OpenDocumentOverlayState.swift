import Foundation

enum OpenDocumentOverlayState: Equatable {
    case none
    case deleteConfirmation
    case pageDeleteConfirmation
    case lock
    case enterPin(OpenDocumentMenuItem)
    case unlockConfirmation
    case signatureDeleteConfirmation(SignatureEntity)
}
