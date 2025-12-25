import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {

    // MARK: - Camera (WeScan core)

    let camera = ScanCameraService()

    private var cancellables = Set<AnyCancellable>()

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
                guard let self else { return }
                self.showPermissionAlert = denied
            }
            .store(in: &cancellables)

        camera.onCapture = { [weak self] image, _ in
            guard let self else { return }
            self.isCapturing = false
            var final = image.downscaled(maxDimension: self.quality.maxDimension)
            // Filters are kept as UI-only for now.
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
        // Torch — постоянный свет
        camera.setTorch(enabled: flashMode == .torch)
    }

    // MARK: - Capture

    func capture() {
        guard !isCapturing else { return }
        isCapturing = true

        // We keep capture controlled by your existing shutter button.
        // WeScan takes care of capture and returns the result via `camera.onCapture`.
        camera.capture()
    }

    func resetSingle() {
        lastCaptured = nil
    }

    func resetGroup() {
        groupCaptures.removeAll()
    }
}
