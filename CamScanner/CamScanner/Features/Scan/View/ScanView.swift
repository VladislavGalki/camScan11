import SwiftUI

struct ScanView: View {

    let onClose: () -> Void

    @StateObject private var vm = ScanViewModel()
    @State private var panel: ScanTopPanel = .none
    @State private var showPreview = false

    var body: some View {
        ZStack {
            DocumentCameraView(camera: vm.camera)
                .ignoresSafeArea()

            Color.black.opacity(0.12).ignoresSafeArea()

            if vm.grid {
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
                    flashMode: vm.flashMode,
                    quality: vm.quality,
                    filter: vm.filter,
                    onSelectFlash: { mode in
                        vm.flashMode = mode
                        vm.applyFlashSideEffects()
                        panel = .none
                    },
                    onSelectQuality: { q in
                        vm.quality = q
                        panel = .none
                    },
                    onSelectFilter: { f in
                        vm.filter = f
                        panel = .none
                    }
                )

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Picker("", selection: $vm.captureMode) {
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
            if newValue != nil, vm.captureMode == .single {
                showPreview = true
            }
        }
    }

    private var flashIconName: String {
        switch vm.flashMode {
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
