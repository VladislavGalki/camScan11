import Foundation

enum FilesNotificationOverlayState: Equatable {
    case deleteFile(UUID)
    case lock(UUID)
    case unlock(UUID)
    case unlockDocument(UUID)
    case none
}
