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

    // Scan-mode (детект)
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // ID-mode (рамка)
    private var latestIdFrameRectInPreview: CGRect?
    private var latestIdPreviewSize: CGSize?

    // MARK: - Output (Scan)
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false

    @Published var lastCaptured: UIImage? = nil
    @Published var lastCapturedOriginal: UIImage? = nil
    @Published var lastAutoQuadInImageSpace: Quadrilateral? = nil

    @Published var groupCaptures: [UIImage] = []

    // MARK: - Output (ID)
    @Published var idResult: IdCaptureResult
    @Published var isIdReadyToPreview: Bool = false

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

        // ✅ стартовое состояние для ID
        self.idResult = IdCaptureResult(
            idType: ui.selectedIdType,
            front: .init(),
            back: ui.selectedIdType.requiresBackSide ? .init() : nil
        )
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

        // Scan auto-shoot engine
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

            let docType = self.ui.getSelectedDocumentType()

            if docType == .id {
                self.handleIdCapture(image: image)
                return
            }

            // ✅ SCAN mode (старый пайплайн)
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

    // MARK: - ID capture pipeline (front/back)
    private func handleIdCapture(image: UIImage) {
        // если интро ещё на экране — ничего не делаем
        guard ui.isIdIntroVisible == false else { return }

        // актуализируем idResult.idType
        if idResult.idType != ui.selectedIdType {
            resetIdFlowForNewType(ui.selectedIdType)
        }

        guard let frameRect = latestIdFrameRectInPreview,
              let previewSize = latestIdPreviewSize,
              previewSize.width > 0, previewSize.height > 0,
              frameRect.width > 1, frameRect.height > 1 else {
            return
        }

        let output = postProcessor.processIdByFrame(
            image: image,
            frameRectInPreview: frameRect,
            previewSize: previewSize,
            quality: ui.quality
        )

        let captured = CapturedFrame(
            preview: output.preview,
            original: output.original,
            quad: output.autoQuadInImageSpace
        )

        // записываем в front/back
        if ui.selectedIdType.requiresBackSide {
            if idResult.back == nil { idResult.back = .init() }

            switch ui.idCaptureSide {
            case .front:
                idResult.front = captured
                ui.idCaptureSide = .back

            case .back:
                idResult.back = captured
            }
        } else {
            idResult.front = captured
            idResult.back = nil
        }

        // готовность
        isIdReadyToPreview = idResult.isReadyForPreview

        // сбрасываем кэш рамки
        latestIdFrameRectInPreview = nil
        latestIdPreviewSize = nil
    }

    private func resetIdFlowForNewType(_ type: IdDocumentTypeEnum) {
        idResult = IdCaptureResult(
            idType: type,
            front: .init(),
            back: type.requiresBackSide ? .init() : nil
        )
        isIdReadyToPreview = false
        ui.idCaptureSide = .front
    }

    // MARK: - Manual crop apply (SCAN)
    func applyManualCropResult(_ croppedOriginalSpace: UIImage) {
        self.lastCapturedOriginal = croppedOriginalSpace
        self.lastAutoQuadInImageSpace = nil

        let preview = croppedOriginalSpace.downscaled(maxDimension: ui.quality.maxDimension)

        switch ui.captureMode {
        case .single:
            self.lastCaptured = preview
        case .group:
            if !groupCaptures.isEmpty {
                groupCaptures[groupCaptures.count - 1] = preview
            } else {
                groupCaptures.append(preview)
            }
        }
    }

    func applyEditedImage(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch ui.captureMode {
            case .single:
                lastCaptured = image
            case .group:
                if !groupCaptures.isEmpty {
                    groupCaptures[groupCaptures.count - 1] = image
                } else {
                    groupCaptures.append(image)
                }
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

        if ui.getSelectedDocumentType() == .id {
            let raw = ui.idFrameRectInCameraSpace

            if let previewSize = camera.previewBoundsSize() {
                let previewRect = CGRect(origin: .zero, size: previewSize)
                let clipped = raw.intersection(previewRect)

                if !clipped.isNull, clipped.width > 10, clipped.height > 10 {
                    latestIdFrameRectInPreview = clipped
                    latestIdPreviewSize = previewSize
                } else {
                    latestIdFrameRectInPreview = nil
                    latestIdPreviewSize = nil
                }
            } else {
                latestIdFrameRectInPreview = nil
                latestIdPreviewSize = nil
            }
        }

        camera.capture()
    }

    func resetSingle() {
        lastCaptured = nil
        lastCapturedOriginal = nil
        lastAutoQuadInImageSpace = nil

        latestIdFrameRectInPreview = nil
        latestIdPreviewSize = nil

        isIdReadyToPreview = false
        // idResult не трогаем тут — зависит от твоего UX
    }

    func resetGroup() {
        groupCaptures.removeAll()
        resetSingle()
    }

    /// если пользователь нажал “Переснять” в ID превью — сбрасываем ID-флоу полностью
    func resetIdCaptures() {
        resetIdFlowForNewType(ui.selectedIdType)
    }
}
