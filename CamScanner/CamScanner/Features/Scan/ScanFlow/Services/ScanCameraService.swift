import AVFoundation
import Combine
import UIKit

final class ScanCameraService: NSObject, ObservableObject {

    @Published private(set) var lastDetectedQuad: Quadrilateral? = nil
    @Published private(set) var lastImageSize: CGSize = .zero
    @Published var authorizationDenied: Bool = false

    private var captureSessionManager: CaptureSessionManager?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var overlayView: DocumentCameraUIView?

    private var isAttached = false
    
    var onCapture: ((UIImage, Quadrilateral?) -> Void)?
    var onQrCodeDetected: ((String) -> Void)?

    func attach(previewLayer: AVCaptureVideoPreviewLayer, overlayView: DocumentCameraUIView) {
        self.previewLayer = previewLayer
        self.overlayView = overlayView

        guard !isAttached else { return }
        isAttached = true

        if let manager = CaptureSessionManager(videoPreviewLayer: previewLayer, delegate: nil) {
            manager.delegate = self
            self.captureSessionManager = manager
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.authorizationDenied = true
            }
        }
    }

    func start() {
        authorizationDenied = false
        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    func stop() {
        captureSessionManager?.stop()
    }

    func capture() {
        captureSessionManager?.capturePhoto()
    }

    func previewBoundsSize() -> CGSize? {
        previewLayer?.bounds.size
    }
    
    func setQRDetecting(_ enabled: Bool) {
        captureSessionManager?.setQRDetecting(enabled)
    }
}

// MARK: - CaptureSessionManagerDelegate
extension ScanCameraService: CaptureSessionManagerDelegate {
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {}

    func captureSessionManager(
        _ captureSessionManager: CaptureSessionManager,
        didDetectQuad quad: Quadrilateral?,
        _ imageSize: CGSize
    ) {
        lastDetectedQuad = quad
        lastImageSize = imageSize
        overlayView?.updateDetectedQuad(quad, imageSize: imageSize)
    }

    func captureSessionManager(
        _ captureSessionManager: CaptureSessionManager,
        didCapturePicture picture: UIImage,
        withQuad quad: Quadrilateral?
    ) {
        onCapture?(picture, quad)
        
        DispatchQueue.main.async { [weak self] in
            self?.overlayView?.clearQuad()
            self?.captureSessionManager?.resumeDetection()
        }
    }

    func captureSessionManager(
        _ captureSessionManager: CaptureSessionManager,
        didFailWithError error: Error
    ) {
        if let scannerError = error as? ImageScannerControllerError,
           scannerError == .authorization {
            authorizationDenied = true
        }
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQRCode code: String) {
        onQrCodeDetected?(code)
    }
}
