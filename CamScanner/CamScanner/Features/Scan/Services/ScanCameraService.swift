import AVFoundation
import Combine
import UIKit

/// Service wrapper around WeScan's `CaptureSessionManager`.
///
/// Goal: keep the live-rectangle detection + preview mapping behavior 1:1 with WeScan,
/// but without any ViewController dependency.
final class ScanCameraService: NSObject, ObservableObject {

    // MARK: - Published output for SwiftUI

    @Published private(set) var lastDetectedQuad: Quadrilateral? = nil
    @Published private(set) var lastImageSize: CGSize = .zero

    // MARK: - Errors / state

    @Published var authorizationDenied: Bool = false

    /// Optional callback for manual capture results.
    /// We keep this as a callback to avoid tying the service to a specific app flow.
    var onCapture: ((UIImage, Quadrilateral?) -> Void)?

    // MARK: - Internal

    private var captureSessionManager: CaptureSessionManager?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var overlayView: DocumentCameraUIView?

    /// Attach the service to an `AVCaptureVideoPreviewLayer` that lives inside a UIView.
    /// This should be called exactly once per view lifetime.
    func attach(previewLayer: AVCaptureVideoPreviewLayer, overlayView: DocumentCameraUIView) {
        self.previewLayer = previewLayer
        self.overlayView = overlayView

        guard captureSessionManager == nil else {
            // Already attached.
            return
        }

        // Create WeScan capture manager with the layer from our view.
        if let manager = CaptureSessionManager(videoPreviewLayer: previewLayer, delegate: nil) {
            manager.delegate = self
            self.captureSessionManager = manager
        } else {
            // If it fails here, we will typically get an error via delegate in WeScan,
            // but in case init returns nil without callback, keep it safe.
            self.authorizationDenied = true
        }
    }

    func start() {
        authorizationDenied = false
        CaptureSession.current.isEditing = false
        // App uses manual shutter. Keep WeScan's auto-scan OFF.
        CaptureSession.current.isAutoScanEnabled = false
        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    func stop() {
        captureSessionManager?.stop()
    }
    
    func resumeLivePreview() {
        overlayView?.clearQuad()
        captureSessionManager?.start()   // или startRunning внутри
    }

    // MARK: - Torch

    func setTorch(enabled: Bool) {
        _ = CaptureSession.current.setTorch(enabled: enabled)
    }

    // MARK: - Manual capture (optional)

    func capture() {
        captureSessionManager?.capturePhoto()
    }
}

// MARK: - RectangleDetectionDelegateProtocol

extension ScanCameraService: RectangleDetectionDelegateProtocol {

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        // Keep WeScan behavior: stop session while processing capture.
        captureSessionManager.stop()
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        // Publish for anyone who wants it, and update overlay exactly like WeScan's CameraScannerViewController.
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
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        // If the user denied camera permission, WeScan uses ImageScannerControllerError.authorization.
        // We map it to our existing SwiftUI alert flag.
        if let scannerError = error as? ImageScannerControllerError,
           scannerError == .authorization {
            authorizationDenied = true
        }
    }
}
