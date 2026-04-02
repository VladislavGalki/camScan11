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

    @EnvironmentObject private var tabBar: TabBarController
    @EnvironmentObject private var router: Router

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
