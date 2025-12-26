import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {

    // MARK: - Core
    let camera = ScanCameraService()

    let settings: ScanSettingsStore
    let ui: ScanUIStateStore

    private let autoShootEngine: AutoShootEngine
    private let postProcessor: CapturePostProcessor

    // подписки — отдельно под камеру
    private var cameraCancellables = Set<AnyCancellable>()
    private var didBindCamera = false

    // Последний quad из превью (координаты детектора) + размер imageSize детектора
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // MARK: - Output
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var lastCaptured: UIImage? = nil
    @Published var groupCaptures: [UIImage] = []

    // MARK: - Init
    init(
        settings: ScanSettingsStore,
        ui: ScanUIStateStore,
        autoShootEngine: AutoShootEngine = AutoShootEngine(),
        postProcessor: CapturePostProcessor = CapturePostProcessor()
    ) {
        self.settings = settings
        self.ui = ui
        self.autoShootEngine = autoShootEngine
        self.postProcessor = postProcessor
    }

    // MARK: - Lifecycle
    func onAppear() {
        bindCameraOnceIfNeeded()
        camera.start()
    }

    func onDisappear() {
        camera.stop()
        camera.setTorch(enabled: false)
    }

    // MARK: - Camera bindings
    private func bindCameraOnceIfNeeded() {
        guard !didBindCamera else { return }
        didBindCamera = true

        camera.$authorizationDenied
            .receive(on: DispatchQueue.main)
            .sink { [weak self] denied in
                self?.showPermissionAlert = denied
            }
            .store(in: &cameraCancellables)

        // ✅ quad + imageSize -> автошот
        camera.$lastDetectedQuad
            .combineLatest(camera.$lastImageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quad, size in
                guard let self else { return }

                self.latestPreviewQuad = quad
                self.latestPreviewImageSize = size

                let canShoot = (!self.isCapturing && self.lastCaptured == nil)
                let shouldShoot = self.autoShootEngine.update(
                    enabled: self.settings.autoShoot,
                    canShoot: canShoot,
                    quad: quad,
                    imageSize: size
                )

                if shouldShoot {
                    self.capture()
                }
            }
            .store(in: &cameraCancellables)

        // ✅ post-process after capture
        camera.onCapture = { [weak self] image, _ in
            guard let self else { return }
            self.isCapturing = false

            let final = self.postProcessor.process(
                image: image,
                previewQuad: self.latestPreviewQuad,
                previewImageSize: self.latestPreviewImageSize,
                autoCrop: self.settings.autoCrop,
                quality: self.ui.quality
            )

            switch self.ui.captureMode {
            case .single:
                self.lastCaptured = final
            case .group:
                self.groupCaptures.append(final)
            }

            self.autoShootEngine.notifyDidCapture()
        }
    }

    // MARK: - Flash / torch
    func applyFlashSideEffects() {
        camera.setTorch(enabled: ui.flashMode == .torch)
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
