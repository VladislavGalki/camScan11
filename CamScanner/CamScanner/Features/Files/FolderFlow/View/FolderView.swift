import SwiftUI

struct FolderView: View {
    @StateObject private var viewModel: FolderViewModel
    
    @State private var selectedFileDocumentItemId: UUID?
    @State private var selectedMenuItem: FilesMenuItem?
    
    @State private var shouldShowDotsOverlay = false
    
    @State private var shouldShowMenuOverlay = false
    @State private var menuFrame: CGRect = .zero
    
    @State private var dotsFrame: CGRect = .zero
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var tabBar: TabBarController
    
    init(
        inputModel: FolderInputModel,
        onFolderDeleted: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: FolderViewModel(
                inputModel: inputModel, onFolderDeleted: onFolderDeleted
            )
        )
    }
    
    var body: some View {
        contentView
            .overlay { menuOverlay }
            .overlay { notificationOverlay }
            .overlay { dotsOverlay }
            .overlay(alignment: .top) { toastOverlay }
            .sheet(item: $viewModel.folderActiveSheet) { sheetView($0) }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            navigationView
            
            switch viewModel.viewState {
            case .empty:
                emptyStateView
            case .success:
                successView
            }
        }
        .navigationBarBackButtonHidden()

        .background(
            Color.bg(.main)
                .ignoresSafeArea()
        )
        .onAppear {
            tabBar.isTabBarVisible = false
        }
    }
    
    private var navigationView: some View {
        HStack(spacing: 0) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.strokeArrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    tabBar.isTabBarVisible = true
                    router.pop()
                }
            )
            
            Spacer(minLength: 0)
            
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.dots),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    shouldShowDotsOverlay = true
                }
            )
            .reportFrame { frame in
                dotsFrame = frame
            }
        }
        .overlay {
            Text(viewModel.folderTitle)
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.main))
                .ignoresSafeArea(edges: .top)
        )
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(appIcon: .empty_folder_image)
            
            Text("Nothing here yet")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
    
    var successView: some View {
        EmptyView()
    }
}

// MARK: - Sheet
private extension FolderView {
    @ViewBuilder
    func sheetView(_ sheet: FolderActiveSheet) -> some View {
        switch sheet {
        case .share:
            EmptyView()
        case let.rename(title):
            RenameFolderView(folderTitle: title) { newTitle in
                viewModel.handleFileDocumentRenamed(selectedFileDocumentItemId, fileName: newTitle)
            }
            .presentationCornerRadius(38)
        case .move:
            EmptyView()
        }
    }
}

// MARK: - Overlay
private extension FolderView {
    var menuOverlay: some View {
        FilesMenuOverlay(
            isVisible: $shouldShowMenuOverlay,
            isLocked: viewModel.isDocumentLocked(id: selectedFileDocumentItemId),
            frame: menuFrame,
            onSelect: handleMenuSelection,
            onClose: {}
        )
    }
    
    var dotsOverlay: some View {
        FolderDotsOverlay(
            isVisible: $shouldShowDotsOverlay,
            isLocked: viewModel.folderItem.isLocked,
            frame: dotsFrame,
            onSelect: handleDotsMenuSelection,
            onClose: {}
        )
    }
    
    var notificationOverlay: some View {
        FolderNotificationOverlay(
            state: viewModel.notificationOverlaystate,
            selectedMenuItem: selectedMenuItem,
            viewModel: viewModel,
            onClear: {
                viewModel.notificationOverlaystate = .none
            }
        )
    }
    
    var toastOverlay: some View {
        Group {
            if viewModel.shouldShowNotification {

                NotificationToast(
                    isPresented: $viewModel.shouldShowNotification,
                    title: viewModel.notificationModel?.title ?? ""
                )
            }
        }
    }
}

// MARK: - Menu Handling
private extension FolderView {
    func handleDotsMenuSelection(_ menuItem: FilesMenuItem) {
        selectedMenuItem = menuItem

        switch menuItem {
        case .delete, .unlockDocument:
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.handleFileDocumentMenuItemSelected(
                    id: viewModel.folderItem.id,
                    menuItem: menuItem,
                    type: .currentFolder
                )
            }
        case .rename:
            viewModel.folderActiveSheet = .rename(viewModel.folderTitle)
        case .lock:
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.notificationOverlaystate = .lock(viewModel.folderItem.id)
            }
        case .move, .share:
            break
        }
    }
    
    func handleMenuSelection(_ menuItem: FilesMenuItem) {
        selectedMenuItem = menuItem

        switch menuItem {
        case .delete, .unlockDocument:
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.handleFileDocumentMenuItemSelected(
                    id: selectedFileDocumentItemId,
                    menuItem: menuItem,
                    type: .documents
                )
            }
        case .rename:
            viewModel.folderActiveSheet = .rename(
                viewModel.getTitleForItem(id: selectedFileDocumentItemId)
            )
        case .lock:
            guard let selectedFileDocumentItemId else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.notificationOverlaystate = .lock(selectedFileDocumentItemId)
            }
        case .move, .share:
            break
        }
    }
}
