import Foundation
import UIKit

struct ScanPreviewModel: Identifiable, Equatable {
    let id = UUID()
    let documentType: DocumentTypeEnum
    var frames: [CapturedFrame]
}

extension ScanPreviewModel {
    mutating func rotateRight() {
        frames = frames.map { RotationService.shared.rotateRight(frame: $0) }
    }

    mutating func rotateLeft() {
        frames = frames.map { RotationService.shared.rotateLeft(frame: $0) }
    }
}
