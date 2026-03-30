import Foundation

enum OpenDocumentOverlayState: Equatable {
    case none
    case deleteConfirmation
    case lock
    case enterPin(OpenDocumentMenuItem)
    case unlockConfirmation
}
