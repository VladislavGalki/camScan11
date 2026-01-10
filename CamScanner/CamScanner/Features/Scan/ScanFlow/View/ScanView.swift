import SwiftUI

struct ScanView: View {

    let onClose: () -> Void

    @StateObject private var settings: ScanSettingsStore
    @StateObject private var ui: ScanUIStateStore
    @StateObject private var vm: ScanViewModel

    @State private var panel: ScanTopPanel = .none
    @State private var showPreview = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose

        let settingsStore = ScanSettingsStore()
        let uiStore = ScanUIStateStore()
        _settings = StateObject(wrappedValue: settingsStore)
        _ui = StateObject(wrappedValue: uiStore)
        _vm = StateObject(wrappedValue: ScanViewModel(settings: settingsStore, ui: uiStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScanTopBar(
                flashIconName: flashIconName,
                onClose: onClose,
                onFlashTap: { toggle(.flash) },
                onQualityTap: { toggle(.quality) },
                onFiltersTap: {
                    if ui.getSelectedDocumentType() == .scan {
                        toggle(.filters)
                    }
                },
                onSettingsTap: { toggle(.settings) },
                isFiltersHidden: ui.getSelectedDocumentType() == .id
            )

            ScanTopPanelsContainer(
                panel: $panel,
                flashMode: ui.flashMode,
                quality: ui.quality,
                filter: ui.filter,
                onSelectFlash: { mode in
                    ui.flashMode = mode
                    vm.applyFlashSideEffects()
                    panel = .none
                },
                onSelectQuality: { q in
                    ui.quality = q
                    panel = .none
                },
                onSelectFilter: { f in
                    ui.filter = f
                    panel = .none
                }
            )

            DocumentCameraView(
                camera: vm.camera,
                isLiveDetectionEnabled: settings.isLivePreviewEnabled && ui.getSelectedDocumentType() == .scan
            )
            .coordinateSpace(name: "cameraSpace")
            .overlay {
                if ui.getSelectedDocumentType() == .id {
                    IdCameraView(ui: ui)
                }
            }
            .overlay {
                if settings.grid {
                    GridOverlay()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if ui.getSelectedDocumentType() == .scan {
                    Picker("", selection: $ui.captureMode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 64)
                    .padding(.bottom, 16)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                DocumentTypeCarouselView(uiState: ui)

                HStack(alignment: .center, spacing: 18) {

                    // слева — заглушка, чтобы шаттер был по центру
                    Color.clear
                        .frame(width: 52, height: 52)

                    ShutterButton(isBusy: vm.isCapturing) {
                        vm.capture()
                    }

                    // справа — мини превью только для group + scan
                    GroupMiniPreviewButton(
                        isVisible: ui.getSelectedDocumentType() == .scan
                            && ui.captureMode == .group
                            && !vm.scanResult.isEmpty,
                        image: vm.scanResult.last?.preview,
                        count: vm.scanResult.count,
                        onTap: { showPreview = true }
                    )
                    .frame(width: 52, height: 52)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(Color.black)
        }
        .overlay {
            if panel == .settings {
                ScanSettingsOverlayCard(isPresented: Binding(
                    get: { panel == .settings },
                    set: { if !$0 { panel = .none } }
                ))
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .alert("Нет доступа к камере", isPresented: $vm.showPermissionAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Разреши доступ к камере в Настройках.")
        }
        .onAppear {
            vm.onAppear()
            vm.applyFlashSideEffects()
            vm.camera.resumeLivePreview()
        }
        .onDisappear {
            vm.onDisappear()
        }
        .fullScreenCover(isPresented: $showPreview) {
            if ui.getSelectedDocumentType() == .scan {
                // ✅ Новый автономный превью + коллбек на редактирование страницы
                ScanCameraPreviewView(
                    inputModel: ScanPreviewInputModel(
                        pages: vm.scanResult,
                        previewMode: .newFromCamera
                    ),
                    onDone: {
                        if ui.captureMode == .group {
                            vm.resetGroup()
                        } else {
                            vm.resetSingle()
                        }
                        showPreview = false
                        onClose()
                    },
                    onRetake: {
                        if ui.captureMode == .group {
                            vm.resetGroup()
                        } else {
                            vm.resetSingle()
                        }
                        showPreview = false
                    },
                    onEditPage: { index, croppedFull, quad in
                        vm.applyManualEditForScan(index: index, croppedOriginal: croppedFull, quad: quad)
                    }
                )
            } else {
                // ✅ ID превью (переименовано)
                IdCameraPreviewView(
                    inputModel: IdPreviewInputModel(
                        result: vm.idResult,
                        previewMode: .newFromCamera
                    ),
                    onDone: {
                        vm.resetIdCaptures()
                        showPreview = false
                        onClose()
                    },
                    onRetake: {
                        vm.resetIdCaptures()
                        showPreview = false
                    },
                    onEdit: { side, cropped, quad in
                        vm.applyManualEditForId(side: side, croppedOriginal: cropped, quad: quad)
                    }
                )
            }
        }
        .onChange(of: vm.lastCaptured) { _, newValue in
            guard newValue != nil else { return }
            if ui.getSelectedDocumentType() == .id { return }
            if ui.captureMode == .single {
                showPreview = true
            }
        }
        .onChange(of: vm.isIdReadyToPreview) { _, ready in
            guard ready else { return }
            if ui.getSelectedDocumentType() == .id {
                showPreview = true
            }
        }
    }

    private var flashIconName: String {
        switch ui.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a"
        case .torch: return "flashlight.on.fill"
        }
    }

    private func toggle(_ target: ScanTopPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            panel = (panel == target) ? .none : target
        }
    }
}
