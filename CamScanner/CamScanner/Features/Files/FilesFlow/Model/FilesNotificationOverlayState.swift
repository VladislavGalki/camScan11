import Foundation

enum FilesNotificationOverlayState: Equatable {
    case deleteFile(UUID)
    case lock(UUID)
    case unlock(UUID)
    case multipleUnlock([UnlockQueueItem])
    case multipleDelete([UUID])
    case unlockDocument(UUID)
    case none
}
