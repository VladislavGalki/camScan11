import SwiftUI

@MainActor
struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    
    @State private var selectedFileDocumentItemId: UUID?
    @State private var selectedMenuItem: FilesMenuItem?
    @State private var shouldShowMenuOverlay = false
    @State private var menuFrame: CGRect = .zero
    @State private var shouldShowDotsOverlay = false
    @State private var dotsFrame: CGRect = .zero
    
    @EnvironmentObject private var tabBar: TabBarController
    
    var body: some View {
        contentView
            .overlay {
                if shouldShowMenuOverlay {
                    LayoutMenuItemView(
                        showGridMenu: $shouldShowMenuOverlay,
                        isItemLocked: viewModel.isDocumentLocked(id: selectedFileDocumentItemId),
                        grideMode: viewModel.viewMode,
                        menuFrame: menuFrame
                    ) { menuItem in
                        selectedMenuItem = menuItem
                        
                        switch menuItem {
                        case .delete:
                            hideTabBar()
                            
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.handleFileDocumentMenuItemSelected(
                                    id: selectedFileDocumentItemId,
                                    menuItem: menuItem
                                )
                            }
                        case .rename:
                            viewModel.fileActiveSheet = .rename
                        case .lock:
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.notificationOverlaystate = .lock
                            }
                        case .unlockDocument:
                            hideTabBar()
                            
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.handleFileDocumentMenuItemSelected(
                                    id: selectedFileDocumentItemId,
                                    menuItem: menuItem
                                )
                            }
                        case .move:
                            break
                        case .share:
                            break
                        }
                    } onClose: {
                        showTabBar()
                    }
                }
            }
            .overlay {
                notificationOverlayView
            }
            .overlay {
                if shouldShowDotsOverlay {
                    DotsMenuView(
                        isVisible: $shouldShowDotsOverlay,
                        dotsFrame: dotsFrame,
                        sortType: viewModel.sortType,
                        viewMode: viewModel.viewMode,
                        onCreateFolder: {
                            viewModel.fileActiveSheet = .createFolder
                        },
                        onSelectFiles: {},
                        onSortChange: { type in
                            viewModel.handleFilesSortType(type: type)
                        },
                        onViewModeChange: { mode in
                            viewModel.viewMode = mode
                        }
                    )
                    .onDisappear {
                        showTabBar()
                    }
                }
            }
            .overlay(alignment: .top) {
                if viewModel.shouldShowNotification {
                    NotificationToast(
                        isPresented: $viewModel.shouldShowNotification,
                        title: viewModel.notificationModel?.title ?? ""
                    )
                }
            }
            .sheet(item: $viewModel.fileActiveSheet) { sheet in
                switch sheet {
                case .createFolder:
                    CreateFolderView { folderName in
                        viewModel.handleFolderCreated(folderName: folderName)
                    }
                    .presentationCornerRadius(38)
                case .rename:
                    RenameFolderView(folderTitle: viewModel.getTitleForItem(id: selectedFileDocumentItemId)) { fileName in
                        viewModel.handleFileDocumentRenamed(selectedFileDocumentItemId, fileName: fileName)
                        clearOverlayState()
                    }
                    .presentationCornerRadius(38)
                }
            }
            .coordinateSpace(name: "filesCoordinateSpace")
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewState {
        case .empty:
            emptyView
        case .success:
            successView
        case .search:
            EmptyView()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(appIcon: .filesEmpty_image)
            
            Text("No Files Yet")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var successView: some View {
        VStack(alignment: .leading, spacing: 0) {
            navigationBarView
            
            switch viewModel.viewMode {
            case .grid:
                gridLayoutView
            case .list:
                listLayoutView
            }
        }
        .background(
            Color.bg(.main)
        )
        .ignoresSafeArea(edges: .top)
    }
    
    private var gridLayoutView: some View {
        GridLayoutView(highlightedID: viewModel.highlightedID, model: viewModel.items) { documentId, isFavourite in
            viewModel.handleDocumentFavourite(documentId: documentId, isFavourite: isFavourite)
        } onMenuClick: { id, buttonFrame in
            selectedFileDocumentItemId = id
            menuFrame = buttonFrame
            hideTabBar()
            shouldShowMenuOverlay = true
        }
    }
    
    private var listLayoutView: some View {
        ListLayoutView(highlightedID: viewModel.highlightedID, model: viewModel.items) { documentId, isFavourite in
            viewModel.handleDocumentFavourite(documentId: documentId, isFavourite: isFavourite)
        } onMenuClick: { id, buttonFrame in
            selectedFileDocumentItemId = id
            menuFrame = buttonFrame
            hideTabBar()
            shouldShowMenuOverlay = true
        }
    }
    
    private var navigationBarView: some View {
        Rectangle()
            .foregroundStyle(.bg(.main))
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Files")
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
                            action: {}
                        )
                        
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.dots),
                                style: .secondary,
                                size: .m
                            ),
                            action: {
                                hideTabBar()
                                shouldShowDotsOverlay = true
                            }
                        )
                        .reportFrame { frame in
                            if dotsFrame == .zero {
                                dotsFrame = frame
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }
    
    private func successNotificationView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(appIcon: .check_circle)
                .renderingMode(.template)
                .foregroundStyle(.elements(.onSuccess))
            
            Text(text)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.onSuccess))
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.bg(.success)
                .cornerRadius(12, corners: .allCorners)
                .appBorderModifier(.border(.onSuccess), radius: 12)
        )
    }
    
    @ViewBuilder
    private var notificationOverlayView: some View {
        if viewModel.notificationOverlaystate != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                
                switch viewModel.notificationOverlaystate {
                case .deleteFile:
                    DeleteDocumentView(
                        onDelete: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedFileDocumentItemId,
                                menuItem: selectedMenuItem
                            )

                            clearOverlayState()
                        },
                        onCancel: {
                            clearOverlayState()
                        }
                    )
                    .onDisappear {
                        showTabBar()
                    }
                case .unlockDocument:
                    UnlockDocumentView(
                        documentTitle: viewModel.getTitleForItem(id: selectedFileDocumentItemId),
                        onRemove: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedFileDocumentItemId,
                                menuItem: selectedMenuItem
                            )
                            
                            clearOverlayState()
                        },
                        onCancel: {
                            clearOverlayState()
                        }
                    )
                    .onDisappear {
                        showTabBar()
                    }
                case .lock:
                    LockDocumentView {
                        await viewModel.handleFaceIdRequest()
                    } onSuccess: { pin, viaFaceId in
                        viewModel.hadleDocumentPinCreated(
                            documentId: selectedFileDocumentItemId,
                            pin: pin,
                            viaFaceId: viaFaceId
                        )
                        
                        clearOverlayState()
                    } onClose: {
                        clearOverlayState()
                    }
                case .unlock:
                    EnterPinView(
                        documentTitle: viewModel.getTitleForItem(id: selectedFileDocumentItemId),
                        validatePin: { pin in
                            return viewModel.handleDocumentPinValidation(
                                documentId: selectedFileDocumentItemId,
                                pin: pin
                            )
                        },
                        onSuccess: {
                            switch selectedMenuItem {
                            case .unlockDocument:
                                viewModel.notificationOverlaystate = .unlockDocument
                            case .delete:
                                viewModel.notificationOverlaystate = .deleteFile
                            default:
                                clearOverlayState()
                            }
                        },
                        onClose: {
                            showTabBar()
                            clearOverlayState()
                        }
                    )
                case .none:
                    EmptyView()
                }
            }
        }
    }
    
    func showTabBar() {
        tabBar.isTabBarVisible = true
    }
    
    func hideTabBar() {
        tabBar.isTabBarVisible = false
    }
    
    private func clearOverlayState() {
        selectedFileDocumentItemId = nil
        selectedMenuItem = nil
        viewModel.notificationOverlaystate = .none
    }
}
