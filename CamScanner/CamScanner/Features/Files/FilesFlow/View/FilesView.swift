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
            .overlay { menuOverlay }
            .overlay { notificationOverlay }
            .overlay { dotsOverlay }
            .overlay(alignment: .top) { toastOverlay }
            .sheet(item: $viewModel.fileActiveSheet) { sheetView($0) }
            .coordinateSpace(name: "filesCoordinateSpace")
    }
}

// MARK: - Content
private extension FilesView {
    @ViewBuilder
    var contentView: some View {
        switch viewModel.viewState {
        case .empty:
            emptyView
        case .success:
            successView
        case .search:
            searchView
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(appIcon: .filesEmpty_image)

            Text("No Files Yet")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxHeight: .infinity)
    }

    var successView: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilesNavigationBarView(
                onDotsTap: {
                    hideTabBar()
                    shouldShowDotsOverlay = true
                },
                onSearchTap: {
                    viewModel.startSearch()
                },
                onDotsFrame: { frame in
                    if dotsFrame == .zero {
                        dotsFrame = frame
                    }
                }
            )

            FilesLayoutContainer(
                mode: viewModel.viewMode,
                items: viewModel.items,
                highlightedID: viewModel.highlightedID,
                onFavourite: { id, isFavourite in
                    viewModel.handleDocumentFavourite(
                        documentId: id,
                        isFavourite: isFavourite
                    )
                },
                onMenuClick: { id, frame in
                    selectedFileDocumentItemId = id
                    menuFrame = frame
                    hideTabBar()
                    shouldShowMenuOverlay = true
                }
            )
        }
        .background(Color.bg(.main))
        .ignoresSafeArea(edges: .top)
    }
    
    private var searchView: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                FilesSearchEmptyView(
                    isSearching: !viewModel.searchText.isEmpty
                )
                .ignoresSafeArea(.keyboard)
            } else {
                FilesSearchResultsView(
                    viewMode: viewModel.viewMode,
                    items: viewModel.items,
                    highlightedID: viewModel.highlightedID
                ) { id, isFavourite in
                    viewModel.handleDocumentFavourite(
                        documentId: id,
                        isFavourite: isFavourite
                    )
                }
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
                text: $viewModel.searchText,
                onClear: viewModel.clearSearch
            )
            .padding(16)
        }
    }
}

// MARK: - Overlays
private extension FilesView {
    var menuOverlay: some View {
        FilesMenuOverlay(
            isVisible: $shouldShowMenuOverlay,
            isLocked: viewModel.isDocumentLocked(id: selectedFileDocumentItemId),
            viewMode: viewModel.viewMode,
            frame: menuFrame,
            onSelect: handleMenuSelection,
            onClose: showTabBar
        )
    }

    var dotsOverlay: some View {
        FilesDotsOverlay(
            isVisible: $shouldShowDotsOverlay,
            frame: dotsFrame,
            sortType: viewModel.sortType,
            viewMode: viewModel.viewMode,
            onCreateFolder: {
                viewModel.fileActiveSheet = .createFolder
            },
            onSort: { viewModel.handleFilesSortType(type: $0) },
            onViewMode: { viewModel.viewMode = $0 },
            onDisappear: showTabBar
        )
    }

    var notificationOverlay: some View {
        FilesNotificationOverlay(
            state: viewModel.notificationOverlaystate,
            selectedID: selectedFileDocumentItemId,
            selectedMenuItem: selectedMenuItem,
            viewModel: viewModel,
            onClear: clearOverlayState,
            onShowTabBar: showTabBar
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

// MARK: - Sheet
private extension FilesView {
    @ViewBuilder
    func sheetView(_ sheet: FileActiveSheet) -> some View {
        switch sheet {
        case .createFolder:
            CreateFolderView { folderName in
                viewModel.handleFolderCreated(folderName: folderName)
            }
            .presentationCornerRadius(38)

        case .rename:
            RenameFolderView(
                folderTitle: viewModel.getTitleForItem(id: selectedFileDocumentItemId)
            ) { fileName in

                viewModel.handleFileDocumentRenamed(
                    selectedFileDocumentItemId,
                    fileName: fileName
                )

                clearOverlayState()
            }
            .presentationCornerRadius(38)
        }
    }
}

// MARK: - Menu Handling
private extension FilesView {
    func handleMenuSelection(_ menuItem: FilesMenuItem) {
        selectedMenuItem = menuItem

        switch menuItem {
        case .delete, .unlockDocument:
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
        case .move, .share:
            break
        }
    }
}

// MARK: - Helpers
private extension FilesView {
    func showTabBar() {
        tabBar.isTabBarVisible = true
    }

    func hideTabBar() {
        tabBar.isTabBarVisible = false
    }

    func clearOverlayState() {
        selectedFileDocumentItemId = nil
        selectedMenuItem = nil
        viewModel.notificationOverlaystate = .none
    }
}

struct FilesNavigationBarView: View {
    let onDotsTap: () -> Void
    let onSearchTap: () -> Void
    let onDotsFrame: (CGRect) -> Void

    var body: some View {
        Rectangle()
            .foregroundStyle(.bg(.main))
            .frame(height: 128)
            .overlay(alignment: .bottom) {
                HStack(spacing: 8) {
                    Text("Files")
                        .appTextStyle(.screenTitle)
                        .foregroundStyle(.text(.primary))

                    Spacer()

                    HStack(spacing: 8) {
                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.search),
                                style: .secondary,
                                size: .m
                            ),
                            action: onSearchTap
                        )

                        AppButton(
                            config: AppButtonConfig(
                                content: .iconOnly(.dots),
                                style: .secondary,
                                size: .m
                            ),
                            action: onDotsTap
                        )
                        .reportFrame { frame in
                            onDotsFrame(frame)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }
}

struct FilesLayoutContainer: View {
    let mode: FilesViewMode
    let items: [FilesGridItem]
    let highlightedID: UUID?
    var shouldHideSettings: Bool = false

    let onFavourite: (UUID, Bool) -> Void
    let onMenuClick: (UUID, CGRect) -> Void

    var body: some View {
        switch mode {
        case .grid:
            GridLayoutView(
                highlightedID: highlightedID,
                model: items,
                shouldHideSettings: shouldHideSettings,
                onFavouriteClick: onFavourite,
                onMenuClick: onMenuClick
            )
        case .list:
            ListLayoutView(
                highlightedID: highlightedID,
                model: items,
                shouldHideSettings: shouldHideSettings,
                onFavouriteClick: onFavourite,
                onMenuClick: onMenuClick
            )
        }
    }
}

struct FilesDotsOverlay: View {
    @Binding var isVisible: Bool

    let frame: CGRect
    let sortType: FilesSortType
    let viewMode: FilesViewMode

    let onCreateFolder: () -> Void
    let onSort: (FilesSortType) -> Void
    let onViewMode: (FilesViewMode) -> Void
    let onDisappear: () -> Void

    var body: some View {
        if isVisible {
            DotsMenuView(
                isVisible: $isVisible,
                dotsFrame: frame,
                sortType: sortType,
                viewMode: viewMode,
                onCreateFolder: onCreateFolder,
                onSelectFiles: {},
                onSortChange: onSort,
                onViewModeChange: onViewMode
            )
            .onDisappear {
                onDisappear()
            }
        }
    }
}

struct FilesMenuOverlay: View {
    @Binding var isVisible: Bool

    let isLocked: Bool
    let viewMode: FilesViewMode
    let frame: CGRect

    let onSelect: (FilesMenuItem) -> Void
    let onClose: () -> Void

    var body: some View {
        if isVisible {
            LayoutMenuItemView(
                showGridMenu: $isVisible,
                isItemLocked: isLocked,
                grideMode: viewMode,
                menuFrame: frame,
                onSelectMenuItem: onSelect,
                onClose: onClose
            )
        }
    }
}

struct FilesNotificationOverlay: View {
    let state: FilesNotificationOverlayState
    
    let selectedID: UUID?
    let selectedMenuItem: FilesMenuItem?
    
    let viewModel: FilesViewModel
    
    let onClear: () -> Void
    let onShowTabBar: () -> Void
    
    var body: some View {
        if state != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                
                switch state {
                case .deleteFile:
                    DeleteDocumentView(
                        onDelete: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedID,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                    .onDisappear {
                        onShowTabBar()
                    }
                case .unlockDocument:
                    UnlockDocumentView(
                        documentTitle: viewModel.getTitleForItem(id: selectedID),
                        onRemove: {
                            viewModel.handleApplyFileDocumentMenuItem(
                                id: selectedID,
                                menuItem: selectedMenuItem
                            )
                            onClear()
                        },
                        onCancel: {
                            onClear()
                        }
                    )
                    .onDisappear {
                        onShowTabBar()
                    }
                case .lock:
                    LockDocumentView {
                        await viewModel.handleFaceIdRequest()
                    } onSuccess: { pin, viaFaceId in
                        viewModel.hadleDocumentPinCreated(
                            documentId: selectedID,
                            pin: pin,
                            viaFaceId: viaFaceId
                        )
                        
                        onClear()
                    } onClose: {
                        onClear()
                    }
                case .unlock:
                    EnterPinView(
                        documentTitle: viewModel.getTitleForItem(id: selectedID),
                        validatePin: { pin in
                            return viewModel.handleDocumentPinValidation(
                                documentId: selectedID,
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
                                onClear()
                            }
                        },
                        onClose: {
                            onShowTabBar()
                            onClear()
                        }
                    )
                case .none:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Search
struct FilesSearchEmptyView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(appIcon: .empty_seatch_image)
                .padding(.bottom, 16)

            Text(
                isSearching
                ? "No Results Found"
                : "Search document and folders"
            )
            .appTextStyle(.bodyPrimary)
            .foregroundStyle(.text(.secondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilesSearchResultsView: View {
    let viewMode: FilesViewMode
    let items: [FilesGridItem]
    let highlightedID: UUID?

    let onFavourite: (UUID, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.bg(.main))
                .frame(height: 62)

            FilesLayoutContainer(
                mode: viewMode,
                items: items,
                highlightedID: highlightedID,
                shouldHideSettings: true,
                onFavourite: onFavourite,
                onMenuClick: { _, _ in }
            )
        }
    }
}

struct FilesSearchBarView: View {
    @Binding var text: String
    let onClear: () -> Void

    var body: some View {
        SearchFieldFileView(text: $text) {
            onClear()
        }
    }
}

struct SearchFieldFileView: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            textField
            
            closeutton
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private var textField: some View {
        HStack(spacing: 8) {
            Image(appIcon: .search)
                .renderingMode(.template)
                .foregroundStyle(.elements(.tertiary))
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Search documents")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.tertiary))
                }
                
                TextField("", text: $text)
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.primary))
                    .tint(.bg(.accent))
                    .focused($isFocused)
            }
            
            if !text.isEmpty {
                Image(appIcon: .closeFill)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.tertiary))
                    .onTapGesture {
                        text = ""
                    }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(
            Color.bg(.controlOnMain)
                .cornerRadius(100)
        )
    }
    
    private var closeutton: some View {
        AppButton(
            config: AppButtonConfig(
                content: .iconOnly(.close),
                style: .secondary,
                size: .m
            )) {
                isFocused = false
                onClose()
            }
    }
}
