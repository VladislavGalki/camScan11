import AVFoundation
import Combine
import UIKit

final class ScanCameraService: NSObject, ObservableObject {

    @Published private(set) var lastDetectedQuad: Quadrilateral? = nil
    @Published private(set) var lastImageSize: CGSize = .zero

    @Published var authorizationDenied: Bool = false

    var onCapture: ((UIImage, Quadrilateral?) -> Void)?

    private var captureSessionManager: CaptureSessionManager?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var overlayView: DocumentCameraUIView?

    private var isAttached = false

    func attach(previewLayer: AVCaptureVideoPreviewLayer, overlayView: DocumentCameraUIView) {
        self.previewLayer = previewLayer
        self.overlayView = overlayView

        guard !isAttached else { return }
        isAttached = true

        if let manager = CaptureSessionManager(videoPreviewLayer: previewLayer, delegate: nil) {
            manager.delegate = self
            self.captureSessionManager = manager
        } else {
            self.authorizationDenied = true
        }
    }

    func start() {
        authorizationDenied = false
        CaptureSession.current.isEditing = false
        CaptureSession.current.isAutoScanEnabled = false

        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    func stop() {
        captureSessionManager?.stop()
    }

    func resumeLivePreview() {
        CaptureSession.current.isEditing = false
        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    func setTorch(enabled: Bool) {
        _ = CaptureSession.current.setTorch(enabled: enabled)
    }

    func capture() {
        captureSessionManager?.capturePhoto()
    }

    // ✅ Preview bounds size (нужно чтобы клиппить rect рамки в пределах превью)
    func previewBoundsSize() -> CGSize? {
        previewLayer?.bounds.size
    }
}

// MARK: - CaptureSessionManagerDelegate
extension ScanCameraService: CaptureSessionManagerDelegate {

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {}

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager,
                               didDetectQuad quad: Quadrilateral?,
                               _ imageSize: CGSize) {
        lastDetectedQuad = quad
        lastImageSize = imageSize
        overlayView?.updateDetectedQuad(quad, imageSize: imageSize)
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager,
                               didCapturePicture picture: UIImage,
                               withQuad quad: Quadrilateral?) {
        onCapture?(picture, quad)

        DispatchQueue.main.async { [weak self] in
            self?.resumeLivePreview()
        }
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager,
                               didFailWithError error: Error) {
        if let scannerError = error as? ImageScannerControllerError,
           scannerError == .authorization {
            authorizationDenied = true
        }
    }
}
