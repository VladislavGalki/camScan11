import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {
    // MARK: - Output (Scan)
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false

    @Published var scanResult: [CapturedFrame] = []
    
    // MARK: - Output (ID)
    @Published var idResult: IdCaptureResult
    @Published var isIdReadyToPreview: Bool = false
    
    // MARK: - QrCode
    @Published var qrCodeResult: String?

    // MARK: - Services
    let camera = ScanCameraService()
    
    //MARK: - Enviornmetns

    let settings: ScanSettingsStore
    let ui: ScanUIStateStore

    private let autoShootEngine: AutoShootEngine
    private let postProcessor: CapturePostProcessor

    private var didBindCamera = false

    // Scan-mode (детект)
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // ID-mode (рамка)
    private var latestIdFrameRectInPreview: CGRect?
    private var latestIdPreviewSize: CGSize?
    
    private var cameraCancellables = Set<AnyCancellable>()
    private var selectedDocumentsCancellable = Set<AnyCancellable>()

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

        self.idResult = IdCaptureResult(
            type: ui.selectedDocumentType,
            back: ui.selectedDocumentType.requiresBackSide
            ? CapturedFrame()
            : nil
        )
        
        subscribeForSelectedDocuments()
        subscribeForCameraService()
    }

    // MARK: - Lifecycle
    func onAppear() {
        camera.start()
    }

    func onDisappear() {
        camera.stop()
    }
    
    private func subscribeForSelectedDocuments() {
        ui.$selectedDocumentType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                self?.resetSessionState(type)
                self?.camera.setQRDetecting(type == .qrCode)
            }
            .store(in: &selectedDocumentsCancellable)
    }

    private func subscribeForCameraService() {
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
                self?.handleLastDetecteCameraQuad(quad: quad, size: size)
            }
            .store(in: &cameraCancellables)

        camera.onCapture = { [weak self] image, _ in
            self?.handleCameraCapture(image: image)
        }
        
        camera.onQrCodeDetected = { [weak self] qrCode in
            self?.handleQrCodeDetected(qrCode: qrCode)
        }
    }
    
    private func handleLastDetecteCameraQuad(quad: Quadrilateral?, size: CGSize) {
        guard self.ui.selectedDocumentType == .documents else {
            self.latestPreviewQuad = nil
            self.latestPreviewImageSize = .zero
            return
        }

        self.latestPreviewQuad = quad
        self.latestPreviewImageSize = size

        let canShoot = !self.isCapturing

        let shouldShoot = self.autoShootEngine.update(
            enabled: self.settings.autoMode,
            canShoot: canShoot,
            quad: quad,
            imageSize: size
        )

        if shouldShoot {
            self.capture()
        }
    }
    
    private func handleCameraCapture(image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            self.isCapturing = false

            if self.ui.selectedDocumentType != .documents {
                self.handleIdCapture(image: image)
                return
            }

            let output = self.postProcessor.process(
                image: image,
                previewQuad: self.latestPreviewQuad,
                previewImageSize: self.latestPreviewImageSize,
                autoMode: self.settings.autoMode && self.ui.selectedDocumentType == .documents,
                quality: self.ui.quality
            )

            let captured = CapturedFrame(
                preview: output.preview,
                original: output.original,
                quad: output.autoQuadInImageSpace
            )
            
            self.scanResult.append(captured)
            self.autoShootEngine.notifyDidCapture()
        }
    }
    
    private func handleQrCodeDetected(qrCode: String) {
        if qrCodeResult != qrCode {
            qrCodeResult = qrCode
        }
    }

    // MARK: - ID capture pipeline (front/back)
    private func handleIdCapture(image: UIImage) {
        if idResult.type != ui.selectedDocumentType {
            resetIdFlowForNewType(ui.selectedDocumentType)
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

        if ui.selectedDocumentType.requiresBackSide {
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

        isIdReadyToPreview = idResult.isReadyForPreview

        latestIdFrameRectInPreview = nil
        latestIdPreviewSize = nil
    }

    private func resetIdFlowForNewType(_ type: DocumentTypeEnum) {
        idResult = IdCaptureResult(
            type: type,
            front: .init(),
            back: type.requiresBackSide ? CapturedFrame() : nil
        )
        isIdReadyToPreview = false
        ui.idCaptureSide = .front
    }
    
    // MARK: - Scan Manual edit apply (как в ID)
    func applyManualEditForScan(index: Int, croppedOriginal: UIImage, quad: Quadrilateral) {
        let preview = croppedOriginal.downscaled(maxDimension: ui.quality.maxDimension)
        guard scanResult.indices.contains(index) else { return }

        scanResult[index].preview = preview
        scanResult[index].quad = quad
    }

    // MARK: - ID Manual edit apply
    func applyManualEditForId(side: IdCaptureSide, croppedOriginal: UIImage, quad: Quadrilateral) {
        let preview = croppedOriginal.downscaled(maxDimension: ui.quality.maxDimension)
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            switch side {
            case .front:
                idResult.front.preview = preview
                idResult.front.quad = quad
            case .back:
                if idResult.back == nil { idResult.back = .init() }
                idResult.back?.preview = preview
                idResult.back?.quad = quad
            }
        }
    }

    // MARK: - Capture
    func capture() {
        guard !isCapturing else { return }
        isCapturing = true

        if ui.selectedDocumentType != .documents {
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

    func resetSessionState(_ type: DocumentTypeEnum) {
        scanResult.removeAll()
        latestPreviewQuad = nil
        latestPreviewImageSize = .zero
        latestIdFrameRectInPreview = nil
        latestIdPreviewSize = nil
        qrCodeResult = nil
        autoShootEngine.resetOnModeChange()
        resetIdFlowForNewType(type)
    }

    func resetIdCaptures() {
        resetIdFlowForNewType(ui.selectedDocumentType)
    }
}
