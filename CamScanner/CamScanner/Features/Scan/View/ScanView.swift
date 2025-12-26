import SwiftUI

struct ScanView: View {

    let onClose: () -> Void

    @StateObject private var settings = ScanSettingsStore()
    @StateObject private var ui = ScanUIStateStore()
    @StateObject private var vm: ScanViewModel

    @State private var panel: ScanTopPanel = .none
    @State private var showPreview = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose

        // Важно: создаём VM с теми же store-объектами
        let settingsStore = ScanSettingsStore()
        let uiStore = ScanUIStateStore()
        _settings = StateObject(wrappedValue: settingsStore)
        _ui = StateObject(wrappedValue: uiStore)
        _vm = StateObject(wrappedValue: ScanViewModel(settings: settingsStore, ui: uiStore))
    }

    var body: some View {
        ZStack {
            DocumentCameraView(camera: vm.camera)
                .ignoresSafeArea()

            Color.black.opacity(0.12).ignoresSafeArea()

            if settings.grid {
                GridOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                ScanTopBar(
                    flashIconName: flashIconName,
                    onClose: onClose,
                    onFlashTap: { toggle(.flash) },
                    onQualityTap: { toggle(.quality) },
                    onFiltersTap: { toggle(.filters) },
                    onSettingsTap: { toggle(.settings) }
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

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Picker("", selection: $ui.captureMode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 64)

                    ScanBottomBar(
                        isCapturing: vm.isCapturing,
                        onShutter: { vm.capture() }
                    )
                }
            }

            if panel == .settings {
                ScanSettingsOverlayCard(isPresented: Binding(
                    get: { panel == .settings },
                    set: { if !$0 { panel = .none } }
                ))
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(Color.black)
        .onAppear {
            vm.onAppear()
            vm.applyFlashSideEffects()
            vm.camera.resumeLivePreview()
        }
        .onDisappear { vm.onDisappear() }
        .alert("Нет доступа к камере", isPresented: $vm.showPermissionAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Разреши доступ к камере в Настройках.")
        }
        .fullScreenCover(isPresented: $showPreview, onDismiss: {
            vm.camera.resumeLivePreview()
        }, content: {
            CapturePreviewView(
                image: vm.lastCaptured,
                onDone: {
                    vm.resetSingle()
                    showPreview = false
                    onClose()
                },
                onRetake: {
                    vm.resetSingle()
                    showPreview = false
                }
            )
        })
        .onChange(of: vm.lastCaptured) { _, newValue in
            if newValue != nil, ui.captureMode == .single {
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
