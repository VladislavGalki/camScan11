import SwiftUI
import PhotosUI

struct AppEntryView: View {

    @State private var selectedTab: AppTab = .home
    @State private var cameraButtonFrame: CGRect = .zero

    @State private var showAddPageSheet = false
    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var importedFileImages: [UIImage] = []
    @State private var shouldShowGlobalToast = false
    @State private var globalToastTitle = ""
    @AppStorage("home.scanButtonOnboardingShown") private var hasShownScanButtonOnboarding = false

    @EnvironmentObject private var tabBar: TabBarController
    @EnvironmentObject private var router: Router
    
    private var shouldShowScanOnboarding: Bool {
        selectedTab == .home
        && tabBar.isTabBarVisible
        && !hasShownScanButtonOnboarding
        && cameraButtonFrame != .zero
        && !showAddPageSheet
        && !showPhotoPicker
        && !showFilePicker
    }

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        TabContainerView(selectedTab: $selectedTab)
            .overlay(alignment: .top) {
                if shouldShowGlobalToast {
                    NotificationToast(
                        isPresented: $shouldShowGlobalToast,
                        title: globalToastTitle
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if tabBar.isTabBarVisible {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        cameraButtonFrame: $cameraButtonFrame,
                        onScanTap: {
                            showAddPageSheet = true
                        }
                    )
                    .transition(.identity.combined(with: .move(edge: .bottom).combined(with: .opacity)))
                }
            }
            .overlay {
                if shouldShowScanOnboarding {
                    ScanButtonOnboardingOverlay(targetFrame: cameraButtonFrame) {
                        hasShownScanButtonOnboarding = true
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: tabBar.isTabBarVisible)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $showAddPageSheet) {
                AddPageBottomSheetView(
                    onTapScan: {
                        router.present(ScanFlowRoute.scan)
                    },
                    onTapImportFromPhotos: {
                        showPhotoPicker = true
                    },
                    onTapImportFromFiles: {
                        showFilePicker = true
                    }
                )
                .presentationDetents([.height(203)])
                .presentationCornerRadius(24)
                .presentationDragIndicator(.hidden)
                .presentationBackground {
                    Color.bg(.main)
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItems,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { items in
                guard !items.isEmpty else { return }
                let pickedItems = items
                selectedPhotoItems = []
                Task {
                    let images = await ImageImportHelper.loadImages(from: pickedItems)
                    guard !images.isEmpty else { return }
                    let inputModel = ImageImportHelper.makeCropperInputModel(from: images)
                    router.present(ScanFlowRoute.importCropper(inputModel))
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerRepresentable { urls in
                    let images = ImageImportHelper.loadImages(from: urls)
                    if !images.isEmpty {
                        importedFileImages = images
                    }
                }
            }
            .onChange(of: importedFileImages) { images in
                guard !images.isEmpty else { return }
                importedFileImages = []
                let inputModel = ImageImportHelper.makeCropperInputModel(from: images)
                router.present(ScanFlowRoute.importCropper(inputModel))
            }
            .onReceive(NotificationCenter.default.publisher(for: .appGlobalToastRequested)) { note in
                guard let title = note.userInfo?["title"] as? String,
                      !title.isEmpty else { return }
                globalToastTitle = title
                shouldShowGlobalToast = true
            }
    }
}

private struct ScanButtonOnboardingOverlay: View {
    let targetFrame: CGRect
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.24)
                    .overlay {
                        Circle()
                            .frame(width: 90, height: 90)
                            .position(x: targetFrame.midX, y: targetFrame.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    tooltipCard
                        .overlay(alignment: .bottom) {
                            Image(appIcon: .small_rect_separator_image)
                                .offset(y: 12)
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, max(110, proxy.size.height - targetFrame.minY + 8))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
    
    private var tooltipCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add your files")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)
            
            Text("Tap the “+” button to scan or upload your first document")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)
            
            AppButton(
                config: AppButtonConfig(
                    content: .title("Got it!"),
                    style: .primary,
                    size: .m,
                    isFullWidth: true
                ),
                action: onDismiss
            )
        }
        .padding([.horizontal, .top], 12)
        .padding(.bottom, 13)
        .background(.bg(.surface))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TooltipPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
