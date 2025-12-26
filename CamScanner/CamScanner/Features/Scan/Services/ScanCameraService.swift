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

    /// Optional callback for capture results.
    var onCapture: ((UIImage, Quadrilateral?) -> Void)?

    // MARK: - Internal

    private var captureSessionManager: CaptureSessionManager?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var overlayView: DocumentCameraUIView?

    private var isAttached = false

    /// Attach the service to an `AVCaptureVideoPreviewLayer` that lives inside a UIView.
    /// This should be called exactly once per view lifetime.
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

    // MARK: - Lifecycle

    func start() {
        authorizationDenied = false

        // Important: these flags affect WeScan internal behavior.
        CaptureSession.current.isEditing = false
        CaptureSession.current.isAutoScanEnabled = false

        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    func stop() {
        captureSessionManager?.stop()
    }

    /// Resume preview + detection after capture / after returning from preview screen.
    func resumeLivePreview() {
        CaptureSession.current.isEditing = false
        overlayView?.clearQuad()
        captureSessionManager?.start()
    }

    // MARK: - Torch

    func setTorch(enabled: Bool) {
        _ = CaptureSession.current.setTorch(enabled: enabled)
    }

    // MARK: - Manual capture

    func capture() {
        captureSessionManager?.capturePhoto()
    }
}

// MARK: - RectangleDetectionDelegateProtocol

extension ScanCameraService: CaptureSessionManagerDelegate {

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {}

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
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

        // ✅ После того как кадр отдали наружу — возвращаем live preview.
        // Это фиксит:
        // 1) group-mode после первого кадра
        // 2) зависание камеры после закрытия превью-экрана
        DispatchQueue.main.async { [weak self] in
            self?.resumeLivePreview()
        }
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        if let scannerError = error as? ImageScannerControllerError,
           scannerError == .authorization {
            authorizationDenied = true
        }
    }
}
