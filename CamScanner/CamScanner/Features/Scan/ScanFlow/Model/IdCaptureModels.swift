import UIKit

enum IdCaptureSide: Equatable {
    case front
    case back
}

struct IdCaptureResult: Equatable {
    var type: DocumentTypeEnum
    var front: CapturedFrame = CapturedFrame()
    var back: CapturedFrame? = nil

    var requiresBackSide: Bool { type.requiresBackSide }

    var isReadyForPreview: Bool {
        if requiresBackSide {
            return front.isReady && (back?.isReady ?? false)
        } else {
            return front.isReady
        }
    }
}
