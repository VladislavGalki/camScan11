import SwiftUI
import AVFoundation
import UIKit

@MainActor
final class ScanViewModel: ObservableObject {

    // MARK: - Camera
    let camera = CameraService()

    // MARK: - Persisted settings used by UI
    @AppStorage(ScanSettingsKeys.grid) var grid: Bool = false
    @AppStorage(ScanSettingsKeys.autoShoot) var autoShoot: Bool = false
    @AppStorage(ScanSettingsKeys.autoCrop) var autoCrop: Bool = true
    @AppStorage(ScanSettingsKeys.textOrientationRotate) var textOrientationRotate: Bool = true
    @AppStorage(ScanSettingsKeys.volumeShutter) var volumeShutter: Bool = true

    // MARK: - UI state / selections
    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single
    @Published var selectedDocumentType: DocumentType = .scan

    // MARK: - Capture result
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var lastCaptured: UIImage? = nil
    @Published var groupCaptures: [UIImage] = []

    // Optional: show processing state / errors if you want UI later
    @Published var isProcessingScan: Bool = false
    @Published var lastScanErrorMessage: String? = nil

    private let processor = DocumentScanProcessor()

    // MARK: - Lifecycle
    func onAppear() { checkPermissionAndStart() }

    func onDisappear() {
        camera.stop()
        camera.setTorch(enabled: false)
    }

    // MARK: - Permission
    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.startCamera() : (self.showPermissionAlert = true)
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    private func startCamera() {
        camera.configureIfNeeded { [weak self] success in
            guard let self, success else { return }

            self.camera.start()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.camera.setUltraWidePreferredZoom(1.15)
            }
        }
    }

    // MARK: - Flash / torch
    func applyFlashSideEffects() {
        camera.setTorch(enabled: flashMode == .torch)
    }

    // MARK: - Capture
    func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        lastScanErrorMessage = nil

        camera.capturePhoto(flashMode: flashMode) { [weak self] image in
            guard let self else { return }
            self.isCapturing = false
            guard var image else { return }

            // Keep your quality downscale (optional)
            image = image.downscaled(maxDimension: self.quality.maxDimension)

            // If user selected "Scan" (document scanning) => run post-capture detection+perspective
            let shouldScan = (self.selectedDocumentType == .scan)

            if shouldScan {
                self.isProcessingScan = true

                Task {
                    do {
                        let scanned = try await self.processor.makeScan(from: image)
                        self.isProcessingScan = false

                        switch self.captureMode {
                        case .single:
                            self.lastCaptured = scanned
                        case .group:
                            self.groupCaptures.append(scanned)
                        }
                    } catch {
                        self.isProcessingScan = false
                        self.lastScanErrorMessage = "Не удалось распознать документ. Попробуй снять ближе/ровнее."

                        // Fallback: keep original photo
                        switch self.captureMode {
                        case .single:
                            self.lastCaptured = image
                        case .group:
                            self.groupCaptures.append(image)
                        }
                    }
                }

            } else {
                // Non-scan types (passport/camera) – keep original for now
                switch self.captureMode {
                case .single:
                    self.lastCaptured = image
                case .group:
                    self.groupCaptures.append(image)
                }
            }
        }
    }

    func resetSingle() { lastCaptured = nil }
    func resetGroup() { groupCaptures.removeAll() }
}

// MARK: - UIImage helper

private extension UIImage {
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return self }

        let s = maxDimension / maxSide
        let newSize = CGSize(width: w * s, height: h * s)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
