import Foundation
import UIKit

struct ScanInputModel {
    enum Mode {
        case regular
        case signature(onCaptured: (UIImage) -> Void)
    }

    var existingDocumentID: UUID?
    let mode: Mode

    init(
        existingDocumentID: UUID? = nil,
        mode: Mode = .regular
    ) {
        self.existingDocumentID = existingDocumentID
        self.mode = mode
    }
}
