import SwiftUI

struct ScanView: View {
    @StateObject private var store: ScanStore
    @StateObject private var vm: ScanViewModel
    
    @State private var hintText: String = ""
    @State private var shouldChangeAutoModeAfterDiscard = false
    @State private var shouldShowDiscardOverlay = false
    @State private var navigationViewHeight: CGFloat = .zero
    
    @EnvironmentObject private var router: Router

    let oncloseClick: () -> Void
    private let existingDocumentID: UUID?

    init(
        inputModel: ScanInputModel = ScanInputModel(),
        oncloseClick: @escaping () -> Void
    ) {
        self.oncloseClick = oncloseClick
        self.existingDocumentID = inputModel.existingDocumentID

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
                .reportHeight { height in
                    navigationViewHeight = height
                }
            
            cameraView
            
            Spacer(minLength: 0)
            
            bottomContainerView
        }
        .overlay {
            if vm.shouldShowQuickPreview, let cropperModel = vm.idDocumentCropperModel {
                QuickDocumentCropperView(
                    store: store,
                    cropperModel: cropperModel,
                    navigationHeight: navigationViewHeight,
                    onRetake: {
                        vm.retakeQuickCrop()
                    },
                    onConfirm: { cropperModel in
                        vm.applyQuickCropForIdsType(cropperModel)
                    }
                )
            }
        }
        .overlay {
            if shouldShowDiscardOverlay {
                dismissOverlayView
            }
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
                    withAnimation {
                        if vm.shouldShowDiscardOverlay {
                            if store.settings.autoMode {
                                shouldChangeAutoModeAfterDiscard = true
                                store.settings.autoMode = false
                            }
                            
                            shouldShowDiscardOverlay = true
                        } else {
                            oncloseClick()
                        }
                    }
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
                        vm.upsateFlashMode()
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
            isLiveDetectionEnabled: store.settings.isLivePreviewEnabled && store.ui.selectedDocumentType == .documents,
            onHintChanged: { state in
                hintText = state.text
            }
        )
        .coordinateSpace(name: "cameraSpace")
        .overlay {
            if store.settings.grid && store.ui.selectedDocumentType == .documents {
                CameraGridView()
            }
        }
        .overlay(alignment: .top) {
            if !hintText.isEmpty {
                Text(hintText)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.onHint))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Color.bg(.hintLight)
                            .cornerRadius(8, corners: .allCorners)
                            .appBorderModifier(.border(.hintNeutral), radius: 8)
                    )
                    .padding(.top, 14)
            }
        }
        .overlay {
            cameraTypeOverlayView
        }
    }
    
    private var bottomContainerView: some View {
        VStack(spacing: 0) {
            DocumentTypeCarouselView(
                store: store,
                shouldHideNonSelectedItems: vm.shouldShowBackBottomBarButton
            )
            
            HStack(spacing: 0) {
                CaptureShutterButton(
                    shouldStartAutoShootCountdown: vm.shouldStartAutoShootCountdown,
                    buttonDisabled: vm.captureShutterButtonDisabled
                ) {
                    vm.capture()
                }
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.back),
                        style: .immersive,
                        size: .m
                    ),
                    action: {
                        vm.resetSessionState(store.ui.selectedDocumentType)
                    }
                )
                .padding(.leading, 37)
                .opacity(vm.shouldShowBackBottomBarButton ? 1 : 0)
            }
            .overlay(alignment: .trailing) {
                MiniPreviewDocumentView(
                    store: store,
                    image: vm.miniPreviewImageForSelectedDocument,
                    count: vm.miniPreviewCountForSelectedDocument,
                    onPreviewClick: {
                        if var inputModel = vm.buildPreviewInputModel() {
                            inputModel.existingDocumentID = existingDocumentID
                            vm.shouldStartAutoShootCountdown = false

                            router.push(
                                ScanRoute.scanPreview(inputModel) { [weak vm] outputModel in
                                    vm?.buildOutputPreview(outputModel)
                                } onSuccessFlow: { [weak vm] in
                                    vm?.shouldStartAutoShootCountdown = false
                                    oncloseClick()
                                }
                            )
                        }
                    }
                )
                .padding(.trailing, 20)
                .disabled(vm.shouldDisableMiniPreview)
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
            IdCardDriverLicenseView(ui: store.ui, shouldShowGrid: store.settings.grid)
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
    
    private var dismissOverlayView: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Discard scans?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))
                    .padding(.bottom, 8)
                
                Text("Your scanned files not be saved")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.secondary))
                    .padding(.bottom, 24)
                
                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Discard scans"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: { oncloseClick() }
                    )
                    
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: {
                            withAnimation {
                                if shouldChangeAutoModeAfterDiscard {
                                    shouldChangeAutoModeAfterDiscard = false
                                    store.settings.autoMode = true
                                }
                                
                                shouldShowDiscardOverlay = false
                            }
                        }
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .foregroundStyle(.bg(.surface))
            )
            .frame(maxWidth: 300)
        }
    }
    
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
    
    private var shouldHideNavigationAndBottombBar: Double {
        vm.shouldShowQuickPreview ? 0 : 1
    }
}
