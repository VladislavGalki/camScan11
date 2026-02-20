import SwiftUI
import Combine
import UIKit

final class ScanViewModel: ObservableObject {
    // MARK: - Scan
    @Published var isCapturing: Bool = false
    @Published var showPermissionAlert: Bool = false

    @Published var scanResult: [CapturedFrame] = []
    
    // MARK: - ID
    @Published var idResult: IdCaptureResult
    @Published var shouldShowQuickPreview: Bool = false
    
    // MARK: - QrCode
    @Published var qrCodeResult: String?

    // MARK: - Services
    let camera = ScanCameraService()
    
    //MARK: - Enviornmetns

    let settings: ScanSettingsStore
    let ui: ScanUIStateStore

    private let autoShootEngine: AutoShootEngine
    private let postProcessor: CapturePostProcessor

    // Scan детект
    private var latestPreviewQuad: Quadrilateral?
    private var latestPreviewImageSize: CGSize = .zero

    // ID рамка
    var idDocumentCropperModel: DocumentCropperModel?
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
            if idResult.back == nil {
                idResult.back = CapturedFrame()
            }

            switch ui.idCaptureSide {
            case .front:
                idResult.front = captured
                startQuickCrop(side: .front, frame: captured)
                return
            case .back:
                idResult.back = captured
                startQuickCrop(side: .back, frame: captured)
                return
            }
        } else {
            idResult.front = captured
            idResult.back = nil
            startQuickCrop(side: .front, frame: captured)
            return
        }
    }
    
    private func startQuickCrop(side: IdCaptureSide, frame: CapturedFrame) {
        if let image = frame.original, let quad = frame.quad {
            idDocumentCropperModel = DocumentCropperModel(image: image, autoQuad: quad)
            shouldShowQuickPreview = true

            latestIdFrameRectInPreview = nil
            latestIdPreviewSize = nil
        }
    }
    
    func retakeQuickCrop() {
        switch ui.idCaptureSide {
        case .front:
            idResult.front = CapturedFrame()
            ui.idCaptureSide = .front
        case .back:
            if idResult.back == nil {
                idResult.back = CapturedFrame()
            }
            idResult.back = CapturedFrame()
            ui.idCaptureSide = .back
        }
        
        shouldShowQuickPreview = false
    }

    private func resetIdFlowForNewType(_ type: DocumentTypeEnum) {
        idResult = IdCaptureResult(
            type: type,
            front: .init(),
            back: type.requiresBackSide ? CapturedFrame() : nil
        )
        ui.idCaptureSide = .front
    }
    
    // MARK: - Scan Manual edit apply
    func applyManualEditForScan(index: Int, croppedOriginal: UIImage, quad: Quadrilateral) {
        let preview = croppedOriginal.downscaled(maxDimension: ui.quality.maxDimension)
        guard scanResult.indices.contains(index) else { return }

        scanResult[index].preview = preview
        scanResult[index].quad = quad
    }

    // MARK: - ID quick crop apply
    
    func applyQuickCropForIdsType(_ cropperModel: DocumentCropperModel) {
        let preview = cropperModel.image.downscaled(maxDimension: ui.quality.maxDimension)

        switch ui.idCaptureSide {
        case .front:
            idResult.front.preview = preview
            idResult.front.quad = cropperModel.autoQuad
            ui.idCaptureSide = ui.selectedDocumentType.requiresBackSide ? .back : .front
        case .back:
            if idResult.back == nil {
                idResult.back = CapturedFrame()
            }
            idResult.back?.preview = preview
            idResult.back?.quad = cropperModel.autoQuad
            ui.idCaptureSide = .front
        }
        
        shouldShowQuickPreview = false
    }
    
    func cancelQuickCrop() {
        switch ui.idCaptureSide {
        case .front:
            idResult.front = CapturedFrame()
            ui.idCaptureSide = .front
        case .back:
            if idResult.back == nil {
                idResult.back = CapturedFrame()
            }
            idResult.back = CapturedFrame()
            ui.idCaptureSide = .back
        }
        
        shouldShowQuickPreview = false
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
    
    // MARK: - Build input/output preview
    
    func buildPreviewInputModel() -> ScanPreviewInputModel? {
        let documentType = ui.selectedDocumentType

        func normalized(_ frames: [CapturedFrame]) -> [CapturedFrame] {
            frames.map {
                var f = $0

                if f.previewBase == nil {
                    f.previewBase = f.drawingBase ?? f.preview
                }

                if f.displayBase == nil {
                    f.displayBase = f.previewBase
                }

                if f.filterHistory.states.isEmpty {
                    f.filterHistory = FilterHistory(
                        states: [FilterState()],
                        currentIndex: 0
                    )
                }

                return f
            }
        }

        switch documentType {
        case .qrCode:
            return nil

        case .documents:
            return ScanPreviewInputModel(
                documentType: documentType,
                pages: [
                    documentType : normalized(scanResult)
                ]
            )
        case .passport:
            return ScanPreviewInputModel(
                documentType: documentType,
                pages: [
                    documentType : normalized([idResult.front])
                ]
            )
        case .idCard:
            var frames: [CapturedFrame] = [idResult.front]
            
            if let back = idResult.back {
                frames.append(back)
            }

            return ScanPreviewInputModel(
                documentType: documentType,
                pages: [
                    documentType : normalized(frames)
                ]
            )
        case .driverLicense:
            var frames: [CapturedFrame] = [idResult.front]

            if let back = idResult.back {
                frames.append(back)
            }

            return ScanPreviewInputModel(
                documentType: documentType,
                pages: [
                    documentType : normalized(frames)
                ]
            )
        }
    }
    
    func buildOutputPreview(_ model: ScanPreviewInputModel) {
        let frames = model.pages[model.documentType] ?? []

        switch model.documentType {
        case .documents:
            scanResult = frames
        case .passport:
            idResult.front = frames.first ?? CapturedFrame()
            idResult.back = nil
        case .idCard, .driverLicense:
            idResult.front = frames.first ?? CapturedFrame()
            idResult.back = frames.count > 1 ? frames[1] : nil
        case .qrCode:
            break
        }
    }
    
    // MARK: - Calculated
    
    var shouldShowDiscardOverlay: Bool {
        !scanResult.isEmpty || (idResult.front.hasPreview || idResult.back?.hasPreview == true)
    }
    
    var captureShutterButtonDisabled: Bool {
        switch ui.selectedDocumentType {
        case .documents:
            return false
        case .idCard, .driverLicense:
            return idResult.front.hasPreview &&
                   idResult.back?.hasPreview == true
        case .passport:
            return idResult.front.hasPreview
        case .qrCode:
            return true
        }
    }
    
    var shouldDisableMiniPreview: Bool {
        switch ui.selectedDocumentType {
        case .documents, .passport, .qrCode:
            return false
        case .idCard, .driverLicense:
            return idResult.back?.displayPreview == nil
        }
    }
    
    var miniPreviewImageForSelectedDocument: UIImage? {
        switch ui.selectedDocumentType {
        case .documents:
            return scanResult.last?.displayPreview
        case .idCard, .driverLicense:
            if let back = idResult.back?.displayPreview {
                return back
            }
            return idResult.front.displayPreview
        case .passport:
            return idResult.front.displayPreview
        case .qrCode:
            return nil
        }
    }
    
    var miniPreviewCountForSelectedDocument: Int {
        switch ui.selectedDocumentType {
        case .documents:
            return scanResult.filter { $0.hasPreview }.count
        case .idCard, .driverLicense:
            let front = idResult.front.hasPreview ? 1 : 0
            let back = idResult.back?.hasPreview == true ? 1 : 0
            return front + back
        case .passport:
            return idResult.front.hasPreview ? 1 : 0
        case .qrCode:
            return 0
        }
    }

    // MARK: - Clean
    func resetSessionState(_ type: DocumentTypeEnum) {
        scanResult.removeAll()
        latestPreviewQuad = nil
        latestPreviewImageSize = .zero
        latestIdFrameRectInPreview = nil
        latestIdPreviewSize = nil
        qrCodeResult = nil
        autoShootEngine.resetOnModeChange()
        idDocumentCropperModel = nil
        resetIdFlowForNewType(type)
    }

    func resetIdCaptures() {
        resetIdFlowForNewType(ui.selectedDocumentType)
    }
}
