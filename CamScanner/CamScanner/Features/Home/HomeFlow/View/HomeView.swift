import SwiftUI
import UIKit

struct HomeView: View {
    @StateObject private var vm: HomeViewModel

    @EnvironmentObject private var router: Router
    @EnvironmentObject private var tabBar: TabBarController
    @Environment(\.dependencies) private var dependencies

    init(dependencies: AppDependencies) {
        _vm = StateObject(wrappedValue: HomeViewModel(dependencies: dependencies))
    }

    @State private var deleteCandidate: DocumentListItem? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var pinDocumentID: UUID?

    @State private var selectedFileDocumentItemId: UUID?
    @State private var selectedMenuItem: FilesMenuItem?
    @State private var shouldShowMenuOverlay = false
    @State private var menuFrame: CGRect = .zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isSearchActive {
                searchView
            } else {
                navigationBarView
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !vm.recentModel.isEmpty {
                            RecentView(model: vm.recentModel) {
                                router.present(ScanFlowRoute.scan)
                            } onDocumentTapped: { item in
                                vm.openDocumentTapped(id: item.id)
                            } onFavoriteTapped: { documentId, isFavorite in
                                vm.handleDocumentFavourite(documentId: documentId, isFavourite: isFavorite)
                            } onMenuClick: { id, frame in
                                selectedFileDocumentItemId = id
                                menuFrame = frame
                                tabBar.isTabBarVisible = false
                                shouldShowMenuOverlay = true
                            }
                            .padding(.bottom, 26)
                        }
                        
                        ExploreToolsView(model: vm.exploreToolModel) {
                        } onToolTapped: { toolType in
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .scrollIndicators(.never)
                .contentMargins(.top, 26, for: .scrollContent)
                .contentMargins(.bottom, Constants.tabBarHeight, for: .scrollContent)
            }
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)
        .coordinateSpace(name: "homeCoordinateSpace")
        .overlay { menuOverlay }
        .overlay { notificationOverlay }
        .overlay(alignment: .top) { toastOverlay }
        .overlay { pinOverlay }
        .sheet(item: $vm.homeActiveSheet) { sheetView($0) }
        .onChange(of: vm.documentToOpen) { _, newValue in
            guard let newValue else { return }
            router.push(HomeRoute.openDocument(id: newValue))
            if vm.isSearchActive {
                vm.clearSearch()
            }
            vm.documentToOpen = nil
        }
        .onChange(of: vm.pinDocumentIDToOpen) { _, newValue in
            pinDocumentID = newValue
        }
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.surface))
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
            .appBorderModifier(.border(.primary), radius: 32, corners: [.bottomLeft, .bottomRight])
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Home")
                        .appTextStyle(.screenTitle)
                        .foregroundStyle(.text(.primary))
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 8) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.search),
                                style: .secondary,
                                size: .m
                            ),
                            action: {
                                vm.startSearch()
                            }
                        )
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .titleWithIcon(
                                    title: "Get PRO",
                                    icon: .starFill
                                ),
                                style: .primary,
                                size: .m
                            ),
                            action: {}
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            if vm.searchItems.isEmpty {
                FilesSearchEmptyView(
                    isSearching: !vm.searchText.isEmpty
                )
                .ignoresSafeArea(.keyboard)
            } else {
                HomeSearchResultsView(
                    items: vm.searchItems,
                    onDocumentClick: { id in
                        vm.openDocumentTapped(id: id)
                    },
                    onFavourite: { id, isFavourite in
                        vm.handleDocumentFavourite(documentId: id, isFavourite: isFavourite)
                    }
                )
                .ignoresSafeArea(edges: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            FilesSearchBarView(
                text: $vm.searchText,
                onClear: vm.clearSearch
            )
            .padding(16)
        }
    }

    @ViewBuilder
    private var pinOverlay: some View {
        if let pinDocumentID {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                EnterPinView(
                    documentTitle: vm.recentModel.first(where: { $0.id == pinDocumentID })?.title
                        ?? vm.searchItems.first(where: { $0.id == pinDocumentID })?.title
                        ?? "",
                    validatePin: { pin in
                        vm.validateDocumentPin(documentId: pinDocumentID, pin: pin)
                    },
                    onSuccess: {
                        vm.finishLockedDocumentOpen(documentId: pinDocumentID)

                        if vm.isSearchActive {
                            vm.clearSearch()
                        }

                        self.pinDocumentID = nil
                    },
                    onClose: {
                        vm.clearPendingPinRequest()
                        self.pinDocumentID = nil
                    }
                )
            }
        }
    }

    // MARK: - Menu Overlays

    private var menuOverlay: some View {
        FilesMenuOverlay(
            isVisible: $shouldShowMenuOverlay,
            isLocked: {
                guard let id = selectedFileDocumentItemId else { return false }
                return vm.isDocumentLocked(id: id)
            }(),
            canMoved: false,
            frame: menuFrame,
            onSelect: handleMenuSelection,
            onClose: { tabBar.isTabBarVisible = true }
        )
    }

    @ViewBuilder
    private var notificationOverlay: some View {
        if vm.notificationOverlayState != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                switch vm.notificationOverlayState {
                case .deleteFile:
                    DeleteDocumentView(
                        onDelete: {
                            vm.handleApplyFileDocumentMenuItem(
                                id: selectedFileDocumentItemId,
                                menuItem: selectedMenuItem
                            )
                            clearMenuState()
                        },
                        onCancel: {
                            clearMenuState()
                        }
                    )
                    .onDisappear {
                        tabBar.isTabBarVisible = true
                    }
                case .unlockDocument:
                    UnlockDocumentView(
                        documentTitle: vm.getTitleForItem(id: selectedFileDocumentItemId),
                        onRemove: {
                            vm.handleApplyFileDocumentMenuItem(
                                id: selectedFileDocumentItemId,
                                menuItem: selectedMenuItem
                            )
                            clearMenuState()
                        },
                        onCancel: {
                            clearMenuState()
                        }
                    )
                    .onDisappear {
                        tabBar.isTabBarVisible = true
                    }
                case .lock:
                    LockDocumentView {
                        await vm.handleFaceIdRequest()
                    } onSuccess: { pin, viaFaceId in
                        vm.handleSetPassword(
                            documentId: selectedFileDocumentItemId,
                            pin: pin,
                            viaFaceId: viaFaceId
                        )
                        clearMenuState()
                    } onClose: {
                        clearMenuState()
                    }
                case let .unlock(id):
                    EnterPinView(
                        documentTitle: vm.getTitleForItem(id: id),
                        validatePin: { pin in
                            vm.validateDocumentPin(documentId: id, pin: pin)
                        },
                        onSuccess: {
                            if let selectedMenuItem {
                                switch selectedMenuItem {
                                case .unlockDocument:
                                    vm.notificationOverlayState = .unlockDocument(id)
                                case .delete:
                                    vm.notificationOverlayState = .deleteFile(id)
                                case .share:
                                    clearMenuState()
                                    tabBar.isTabBarVisible = true
                                    vm.processSuccessMenuItemSelection(id: id, menuItem: selectedMenuItem)
                                default:
                                    clearMenuState()
                                }
                            } else {
                                clearMenuState()
                            }
                        },
                        onClose: {
                            tabBar.isTabBarVisible = true
                            clearMenuState()
                        }
                    )
                default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if vm.shouldShowNotification {
            NotificationToast(
                isPresented: $vm.shouldShowNotification,
                title: vm.notificationModel?.title ?? ""
            )
        }
    }

    // MARK: - Menu Handling

    private func handleMenuSelection(_ menuItem: FilesMenuItem) {
        selectedMenuItem = menuItem

        switch menuItem {
        case .delete, .unlockDocument:
            tabBar.isTabBarVisible = false

            withAnimation(.easeInOut(duration: 0.15)) {
                vm.handleFileDocumentMenuItemSelected(
                    id: selectedFileDocumentItemId,
                    menuItem: menuItem
                )
            }
        case .rename:
            vm.homeActiveSheet = .rename
        case .lock:
            tabBar.isTabBarVisible = false

            withAnimation(.easeInOut(duration: 0.15)) {
                vm.notificationOverlayState = .lock(UUID())
            }
        case .move:
            vm.handleMoveDocument(id: selectedFileDocumentItemId)
        case .share:
            withAnimation(.easeInOut(duration: 0.15)) {
                vm.handleFileDocumentMenuItemSelected(
                    id: selectedFileDocumentItemId,
                    menuItem: menuItem
                )
            }
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private func sheetView(_ sheet: FileActiveSheet) -> some View {
        switch sheet {
        case let .share(id):
            if let shareInputModel = vm.makeShareModel(id: id) {
                ShareView(inputModel: shareInputModel, dependencies: dependencies) {
                    vm.homeActiveSheet = nil
                }
                .presentationCornerRadius(38)
            }
        case .rename:
            RenameFolderView(
                folderTitle: vm.getTitleForItem(id: selectedFileDocumentItemId)
            ) { fileName in
                vm.handleFileDocumentRenamed(
                    selectedFileDocumentItemId,
                    fileName: fileName
                )
                clearMenuState()
            }
            .presentationCornerRadius(38)
        case let .move(inputModel):
            MoveDocumentsView(
                inputModel: inputModel,
                onMove: { documentIds, folderId in
                    vm.handleDocumentMoved(documentIds: documentIds, folderId: folderId)
                },
                dependencies: dependencies
            )
            .presentationCornerRadius(38)
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func clearMenuState() {
        if selectedMenuItem == .lock {
            tabBar.isTabBarVisible = true
        }

        selectedFileDocumentItemId = nil
        selectedMenuItem = nil
        vm.notificationOverlayState = .none
    }
}

private struct HomeSearchResultsView: View {
    let items: [FilesGridItem]
    let onDocumentClick: (UUID) -> Void
    let onFavourite: (UUID, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.bg(.main))
                .frame(height: 62)

            FilesLayoutContainer(
                mode: .list,
                items: items,
                highlightedID: nil,
                shouldHideSettings: true,
                onFolderClick: { _ in },
                onDocumentClick: onDocumentClick,
                onFavourite: onFavourite,
                onMenuClick: { _, _ in }
            )
        }
    }
}
