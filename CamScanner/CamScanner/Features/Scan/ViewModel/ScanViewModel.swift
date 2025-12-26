import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {

    // MARK: - Camera (WeScan core)

    let camera = ScanCameraService()
    private var cancellables = Set<AnyCancellable>()

    // Последний quad из превью (координаты детектора) + размер imageSize детектора
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // MARK: - Persisted settings used by UI

    @AppStorage(ScanSettingsKeys.grid) var grid: Bool = false
    @AppStorage(ScanSettingsKeys.autoShoot) var autoShoot: Bool = false
    @AppStorage(ScanSettingsKeys.autoCrop) var autoCrop: Bool = true
    @AppStorage(ScanSettingsKeys.textOrientationRotate) var textOrientationRotate: Bool = true
    @AppStorage(ScanSettingsKeys.volumeShutter) var volumeShutter: Bool = true

    // MARK: - UI state

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

    // MARK: - Lifecycle

    func onAppear() {
        bindCamera()
        camera.start()
    }

    func onDisappear() {
        camera.stop()
        camera.setTorch(enabled: false)
    }

    // MARK: - Bindings

    private func bindCamera() {
        guard cancellables.isEmpty else { return }

        camera.$authorizationDenied
            .receive(on: DispatchQueue.main)
            .sink { [weak self] denied in
                self?.showPermissionAlert = denied
            }
            .store(in: &cancellables)

        // ✅ держим актуальный quad из превью (в координатах детектора)
        camera.$lastDetectedQuad
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quad in
                self?.latestPreviewQuad = quad
            }
            .store(in: &cancellables)

        camera.$lastImageSize
            .receive(on: DispatchQueue.main)
            .sink { [weak self] size in
                self?.latestPreviewImageSize = size
            }
            .store(in: &cancellables)

        camera.onCapture = { [weak self] image, _ in
            guard let self else { return }
            self.isCapturing = false

            var final = image

            // ✅ Кропаем по quad из превью, но ТОЛЬКО после scale в систему координат фото
            if self.autoCrop,
               let previewQuad = self.latestPreviewQuad,
               self.latestPreviewImageSize.width > 0,
               self.latestPreviewImageSize.height > 0 {

                let angle = SmartCropper.rotationAngle(for: final.imageOrientation)

                // Масштабируем quad (детектор -> image.size) и учитываем rotationAngle (как WeScan)
                let quadInImageSpace = previewQuad.scale(self.latestPreviewImageSize, final.size, withRotationAngle: angle)

                if let cropped = SmartCropper.cropAndDeskew(image: final, quad: quadInImageSpace) {
                    final = cropped
                }
            }

            // ✅ downscale ПОСЛЕ кропа
            final = final.downscaled(maxDimension: self.quality.maxDimension)

            switch self.captureMode {
            case .single:
                self.lastCaptured = final
            case .group:
                self.groupCaptures.append(final)
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
        camera.capture()
    }

    func resetSingle() { lastCaptured = nil }
    func resetGroup() { groupCaptures.removeAll() }
}
