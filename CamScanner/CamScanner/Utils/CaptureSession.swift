import AVFoundation
import Foundation

final class CaptureSession {
    static let current = CaptureSession()

    var device: CaptureDevice?
    var editImageOrientation: CGImagePropertyOrientation

    private init(editImageOrientation: CGImagePropertyOrientation = .up) {
        self.device = AVCaptureDevice.default(for: .video)
        self.editImageOrientation = editImageOrientation
    }
}
