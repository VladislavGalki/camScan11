import SwiftUI
import AVFoundation
import UIKit

final class ScanViewModel: ObservableObject {

    // MARK: - Camera

    let camera = CameraService()

    // MARK: - Persisted settings used by UI

    @AppStorage(ScanSettingsKeys.grid) var grid: Bool = false
    @AppStorage(ScanSettingsKeys.autoShoot) var autoShoot: Bool = false           // пока не используется (без Vision)
    @AppStorage(ScanSettingsKeys.autoCrop) var autoCrop: Bool = true              // пока не используется (без Vision)
    @AppStorage(ScanSettingsKeys.textOrientationRotate) var textOrientationRotate: Bool = true
    @AppStorage(ScanSettingsKeys.volumeShutter) var volumeShutter: Bool = true

    // MARK: - UI state / selections (must exist for panels)

    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single
    @Published var selectedDocumentType: DocumentType = .scan // UI карусель (пока 1 элемент)

    // MARK: - Capture result

    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var lastCaptured: UIImage? = nil
    @Published var groupCaptures: [UIImage] = [] // на будущее; сейчас можно не использовать

    // MARK: - Lifecycle

    func onAppear() {
        checkPermissionAndStart()
    }

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

            // Ultra-wide по умолчанию + лёгкий “0.57x” эквивалент (как ты подобрал)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.camera.setUltraWidePreferredZoom(1.15)
            }
        }
    }

    // MARK: - Flash / torch

    func applyFlashSideEffects() {
        // Torch — постоянный свет
        camera.setTorch(enabled: flashMode == .torch)
    }

    // MARK: - Capture

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true

        camera.capturePhoto(flashMode: flashMode) { [weak self] image in
            guard let self else { return }
            self.isCapturing = false
            guard var image else { return }

            // В режиме “чистой камеры” мы НЕ делаем Vision/PDF.
            // Качество можно оставить как downscale (не относится к Vision/PDF).
            image = image.downscaled(maxDimension: self.quality.maxDimension)

            // Фильтры пока НЕ применяем (так как ты откатился “до сканера”).
            // Оставляем выбор в UI, применение добавим позже отдельным шагом.

            switch self.captureMode {
            case .single:
                self.lastCaptured = image
            case .group:
                self.groupCaptures.append(image)
                // если захочешь — можно открывать превью только по кнопке “Готово”
            }
        }
    }

    func resetSingle() {
        lastCaptured = nil
    }

    func resetGroup() {
        groupCaptures.removeAll()
    }
}
