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

    private var cameraCancellables = Set<AnyCancellable>()
    private var didBindCamera = false

    // Последний quad из превью (координаты детектора) + размер imageSize детектора
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // MARK: - Output
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false

    /// То, что показываем на экране превью (обычно: уже downscale + возможно autoCrop)
    @Published var lastCaptured: UIImage? = nil

    /// Оригинальный кадр (полный, не downscale), нужен для ручной обрезки
    @Published var lastCapturedOriginal: UIImage? = nil

    /// Quad в координатах оригинального изображения, который использовали для autoCrop (если был)
    @Published var lastAutoQuadInImageSpace: Quadrilateral? = nil

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

        camera.onCapture = { [weak self] image, _ in
            guard let self else { return }
            self.isCapturing = false

            let output = self.postProcessor.process(
                image: image,
                previewQuad: self.latestPreviewQuad,
                previewImageSize: self.latestPreviewImageSize,
                autoCrop: self.settings.autoCrop,
                quality: self.ui.quality
            )

            self.lastCapturedOriginal = output.original
            self.lastAutoQuadInImageSpace = output.autoQuadInImageSpace

            switch self.ui.captureMode {
            case .single:
                self.lastCaptured = output.preview
            case .group:
                self.groupCaptures.append(output.preview)
            }

            self.autoShootEngine.notifyDidCapture()
        }
    }

    // MARK: - Manual crop apply (вызываем после DocumentCropperView)
    func applyManualCropResult(_ croppedOriginalSpace: UIImage) {
        // после ручной обрезки:
        // - превью = downscale по выбранному quality
        // - original = тоже можно заменить на кропнутый (если дальше нужно)
        self.lastCapturedOriginal = croppedOriginalSpace
        self.lastAutoQuadInImageSpace = nil

        let preview = croppedOriginalSpace.downscaled(maxDimension: ui.quality.maxDimension)

        switch ui.captureMode {
        case .single:
            self.lastCaptured = preview
        case .group:
            // для группового — заменим последний кадр, т.к. редактируем “текущий”
            if !groupCaptures.isEmpty {
                groupCaptures[groupCaptures.count - 1] = preview
            } else {
                groupCaptures.append(preview)
            }
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

    func resetSingle() {
        lastCaptured = nil
        lastCapturedOriginal = nil
        lastAutoQuadInImageSpace = nil
    }

    func resetGroup() {
        groupCaptures.removeAll()
        lastCaptured = nil
        lastCapturedOriginal = nil
        lastAutoQuadInImageSpace = nil
    }
}
