import SwiftUI

struct ScanView: View {
    @StateObject private var store: ScanStore
    @StateObject private var vm: ScanViewModel
    
    @State private var showPreview = false
    
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let store = ScanStore()
        _store = StateObject(wrappedValue: store)
        _vm = StateObject(wrappedValue: ScanViewModel(settings: store.settings, ui: store.ui))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.leading, 16)
                .padding(.trailing, 26)
                .padding(.bottom, 16)
            
            cameraView
            
            Spacer(minLength: 0)
            
            bottomContainerView
        }
        .background(
            Color.bg(.immersive)
                .ignoresSafeArea()
        )
        .onAppear {
            vm.onAppear()
        }
        .onDisappear {
            vm.onDisappear()
        }
    }
    
    private var navigationView: some View {
        HStack(spacing: 0) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .immersive,
                    size: .m
                ),
                action: {
                    onClose()
                }
            )
            
            Spacer(minLength: 0)
            
            HStack(spacing: 16) {
                Image(appIcon: navigationFlashIcon)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.onImmersive))
                    .frame(width: 24, height: 24)
                    .onTapGesture {
                        store.ui.toggleFlashMode()
                    }
                
                Image(appIcon: store.settings.grid ? .grid : .gridOff)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.onImmersive))
                    .frame(width: 24, height: 24)
                    .onTapGesture {
                        store.settings.grid.toggle()
                    }
            }
            .opacity(navigationFlashAndGridOpacity)
        }
        .overlay {
            AppButton(
                config: AppButtonConfig(
                    content: .titleWithIcon(
                        title: navigationAutoModeTitle,
                        icon: .backForward,
                        placement: .leading
                    ),
                    style: .immersive,
                    size: .m
                ),
                action: {
                    store.settings.autoMode.toggle()
                }
            )
            .opacity(navigationAutoModeOpacity)
        }
    }
    
    private var cameraView: some View {
        DocumentCameraView(
            camera: vm.camera,
            isLiveDetectionEnabled: store.settings.isLivePreviewEnabled && store.ui.selectedDocumentType == .documents
        )
        .coordinateSpace(name: "cameraSpace")
        .overlay {
            cameraTypeOverlayView
        }
    }
    
    private var bottomContainerView: some View {
        VStack(spacing: 0) {
            DocumentTypeCarouselView(store: store)
            
            HStack(spacing: 0) {
                CaptureShutterButton(
                    shoudStartTimer: false,
                    buttonDisabled: captureShutterButtonDisabled
                ) {
                    vm.capture()
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                MiniPreviewDocumentView(
                    store: store,
                    image: miniPreviewImageForSelectedDocument,
                    count: miniPreviewCountForSelectedDocument,
                    onPreviewClick: {
                        showPreview = true
                    }
                )
                .padding(.trailing, 20)
            }
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .padding(.top, 16)
        .background(Color.bg(.immersive))
    }
    
    @ViewBuilder
    private var cameraTypeOverlayView: some View {
        if store.ui.selectedDocumentType == .idCard
            || store.ui.selectedDocumentType == .driverLicense {
            IdCardDriverLicenseView(ui: store.ui)
        } else if store.ui.selectedDocumentType == .qrCode {
            QrCodeView(
                ui: store.ui,
                qrCodeResult: vm.qrCodeResult
            ) {
                vm.qrCodeResult = nil
            }
        } else if store.ui.selectedDocumentType == .passport {
            PassportView(ui: store.ui)
        }
    }
    
//        }
//        .fullScreenCover(isPresented: $showPreview) {
//            if ui.getSelectedDocumentType() == .documents {
//                DocumentPreviewView(
//                    inputModel: .scan(
//                        pages: vm.scanResult,
//                        previewMode: .newFromCamera,
//                        rememberedFilterKey: nil
//                    ),
//                    onDone: {
//                        if ui.captureMode == .group {
//                            vm.resetGroup()
//                        } else {
//                            vm.resetSingle()
//                        }
//                        showPreview = false
//                        onClose()
//                    },
//                    onRetake: {
//                        if ui.captureMode == .group {
//                            vm.resetGroup()
//                        } else {
//                            vm.resetSingle()
//                        }
//                        showPreview = false
//                    },
//                    onEditPage: { index, croppedFull, quad in
//                        vm.applyManualEditForScan(index: index, croppedOriginal: croppedFull, quad: quad)
//                    }
//                )
//            } else {
//                DocumentPreviewView(
//                    inputModel: .id(
//                        result: vm.idResult,
//                        previewMode: .newFromCamera,
//                        rememberedFilterKey: nil
//                    ),
//                    onDone: {
//                        vm.resetIdCaptures()
//                        showPreview = false
//                        onClose()
//                    },
//                    onRetake: {
//                        vm.resetIdCaptures()
//                        showPreview = false
//                    },
//                    onEditPage: { index, croppedFull, quad in
//                        let side: IdCaptureSide = (index == 0 ? .front : .back)
//                        vm.applyManualEditForId(side: side, croppedOriginal: croppedFull, quad: quad)
//                    }
//                )
//            }
//        }
    
    private var navigationFlashIcon: AppIcon {
        switch store.ui.flashMode {
        case .off: .flashOff
        case .on: .flash
        case .auto: .flashAuto
        }
    }
    
    private var navigationAutoModeTitle: String {
        store.settings.autoMode ? "Auto" : "Manual"
    }
    
    private var navigationFlashAndGridOpacity: Double {
        store.ui.selectedDocumentType != .qrCode ? 1.0 : 0.0
    }
    
    private var navigationAutoModeOpacity: Double {
        store.ui.selectedDocumentType == .documents ? 1.0 : 0.0
    }
    
    private var captureShutterButtonDisabled: Bool {
        switch store.ui.selectedDocumentType {
        case .documents:
            return false
        case .idCard, .driverLicense:
            return vm.idResult.front.preview != nil && vm.idResult.back?.preview != nil
        case .passport:
            return vm.idResult.front.preview != nil
        case .qrCode:
            return true
        }
    }
    
    private var miniPreviewImageForSelectedDocument: UIImage? {
        switch store.ui.selectedDocumentType {
        case .documents:
            return vm.scanResult.last?.preview
        case .idCard, .driverLicense:
            if let backImage = vm.idResult.back?.preview {
                return backImage
            } else if let frontImage = vm.idResult.front.preview {
                return frontImage
            } else {
                return nil
            }
        case .passport:
            if let frontImage = vm.idResult.front.preview {
                return frontImage
            } else {
                return nil
            }
        case .qrCode:
            return nil
        }
    }
    
    private var miniPreviewCountForSelectedDocument: Int {
        switch store.ui.selectedDocumentType {
        case .documents:
            return vm.scanResult.count
        case .idCard, .driverLicense:
            if vm.idResult.back?.preview != nil {
                return 2
            } else if vm.idResult.front.preview != nil {
                return 1
            }
            return 0
        case .passport:
            return 1
        case .qrCode:
            return 0
        }
    }
}
