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

    @EnvironmentObject private var router: Router
    @EnvironmentObject private var tabBar: TabBarController

    var body: some View {
        contentView
            .overlay(alignment: .top) { toastOverlay }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.isSelectable {
                    selectableBottomBar
                }
            }
            .overlay { menuOverlay }
            .overlay { notificationOverlay }
            .overlay { dotsOverlay }
            .sheet(item: $viewModel.fileActiveSheet) { sheetView($0) }
            .coordinateSpace(name: "filesCoordinateSpace")
            .onChange(of: viewModel.folderToOpen) { _, newValue in
                guard let newValue else { return }
                presentFolderView(newValue)
                viewModel.folderToOpen = nil
            }
            .onChange(of: viewModel.documentToOpen) { _, newValue in
                guard let newValue else { return }
                router.push(FilesRoute.openDocument(OpenDocumentInputModel(documentID: newValue)))
                viewModel.documentToOpen = nil
            }
            .onChange(of: viewModel.isSelectable) { _, newValue in
                tabBar.isTabBarVisible = !newValue
            }
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
            if !viewModel.isSelectable {
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
            } else {
                selectableNavigationView
            }

            FilesLayoutContainer(
                mode: viewModel.viewMode,
                items: viewModel.items,
                highlightedID: viewModel.highlightedID,
                shouldHideAllSettings: viewModel.isSelectable,
                onFolderClick: { id in
                    if viewModel.isSelectable {
                        viewModel.handleDocumentSelected(id: id)
                        return
                    }
                    
                    viewModel.openFolderTapped(id: id)
                },
                onDocumentClick: { id in
                    if viewModel.isSelectable {
                        viewModel.handleDocumentSelected(id: id)
                        return
                    }

                    viewModel.openDocumentTapped(id: id)
                },
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
    
    private var selectableNavigationView: some View {
        Rectangle()
            .foregroundStyle(.bg(.main))
            .frame(height: 128)
            .overlay(alignment: .bottom) {
                HStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .iconOnly(.close),
                            style: .secondary,
                            size: .m
                        ),
                        action: {
                            withAnimation {
                                viewModel.isSelectable = false
                                viewModel.handleClearSelection()
                            } completion: {
                                tabBar.isTabBarVisible = true
                            }
                        }
                    )
                    
                    Spacer(minLength: 0)
                    
                    Text("Select All")
                        .appTextStyle(.bodyPrimary)
                        .foregroundStyle(.text(.accent))
                        .onTapGesture {
                            viewModel.handleSelectAll()
                        }
                }
                .overlay {
                    Text("\(viewModel.selectedIDs.count) selected")
                        .appTextStyle(.topBarTitle)
                        .foregroundStyle(.text(.primary))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
    }
    
    private var selectableBottomBar: some View {
        HStack(spacing: 0) {
            selectableBottomBarItem(title: "Move", icon: .move)
            selectableBottomBarItem(title: "Share", icon: .share)
            selectableBottomBarItem(title: "Merge", icon: .merge)
            selectableBottomBarItem(title: "Delete", icon: .trash, destructive: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .ignoresSafeArea(edges: .bottom)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func selectableBottomBarItem(
        title: String,
        icon: AppIcon,
        destructive: Bool = false
    ) -> some View {
        let isEmpty = viewModel.selectedIDs.isEmpty
        
        let buttonType: FilesSelectableMenuItem? = {
            switch icon {
            case .move:
                return .move
            case .share:
                return .share
            case .merge:
                return .merge
            case .trash:
                return .delete
            default:
                return nil
            }
        }()

        let iconStyle: Color = {
            if isEmpty {
                return destructive
                ? .elements(.destructiveDisabled)
                : .elements(.disabled)
            } else {
                return destructive
                ? .elements(.destructive)
                : .elements(.secondary)
            }
        }()

        let textStyle: Color = {
            if isEmpty {
                return destructive
                ? .text(.destructiveDisabled)
                : .text(.disabled)
            } else {
                return destructive
                ? .text(.destructive)
                : .text(.secondary)
            }
        }()

        return VStack(spacing: 4) {
            Image(appIcon: icon)
                .renderingMode(.template)
                .foregroundStyle(iconStyle)

            Text(title)
                .appTextStyle(.tabBar)
                .foregroundStyle(textStyle)

        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .onTapGesture {
            if !isEmpty {
                viewModel.handleSelectableMenuItem(menuItem: buttonType)
            }
        }
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
                    highlightedID: viewModel.highlightedID,
                    onFolderClick: { id in
                        viewModel.openFolderTapped(id: id)
                        viewModel.clearSearch()
                    },
                    onDocumentClick: { id in
                        viewModel.openDocumentTapped(id: id)
                    },
                    onFavourite: { id, isFavourite in
                        viewModel.handleDocumentFavourite(
                            documentId: id,
                            isFavourite: isFavourite
                        )
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
                text: $viewModel.searchText,
                onClear: viewModel.clearSearch
            )
            .padding(16)
        }
    }
    
    // MARK: Private
    private func presentFolderView(_ id: UUID) {
        if let folderItem = viewModel.getFolderItem(id: id) {
            router.push(
                FilesRoute.openFolder(
                    FolderInputModel(
                        folderItem: folderItem,
                        viewMode: viewModel.viewMode
                    ),
                    onFolderDeleted: {
                        router.pop()
                        
                        Task {
                            try await Task.sleep(for: .seconds(0.25))
                            viewModel.showNotification(type: .folderRemoved)
                        }
                    }
                )
            )
        }
    }
}

// MARK: - Overlays
private extension FilesView {
    var menuOverlay: some View {
        FilesMenuOverlay(
            isVisible: $shouldShowMenuOverlay,
            isLocked: viewModel.isDocumentLocked(id: selectedFileDocumentItemId),
            canMoved: viewModel.typeForItem(id: selectedFileDocumentItemId) == .folder,
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
            onSelectFiles: {
                withAnimation {
                    viewModel.isSelectable = true
                }
            },
            onSort: { viewModel.handleFilesSortType(type: $0) },
            onViewMode: { viewModel.viewMode = $0 },
            onDisappear: {
                if !viewModel.isSelectable {
                    showTabBar()
                }
            }
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
        case let .share(id):
            if let shareInputModel = viewModel.makeShareModel(id: id) {
                ShareView(inputModel: shareInputModel) {
                    viewModel.fileActiveSheet = nil
                }
                .presentationCornerRadius(38)
            }
        case let .multipleShare(ids):
            if let shareInputModel = viewModel.makeShareModel(ids: ids) {
                ShareView(inputModel: shareInputModel) {
                    viewModel.fileActiveSheet = nil
                }
                .presentationCornerRadius(38)
            }
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
        case let .move(inputModel):
            MoveDocumentsView(inputModel: inputModel) { documentIds, folderId in
                viewModel.handleDocumentMoved(documentIds: documentIds, folderId: folderId)
            }
            .presentationCornerRadius(38)
        case let .merge(inputModel):
            MergeDocumentsView(inputModel: inputModel) {
                viewModel.handleClearSelection()
                viewModel.fileActiveSheet = nil
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
            tabBar.isTabBarVisible = false
            
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.notificationOverlaystate = .lock(UUID())
            }
        case .move:
            viewModel.handleMoveDocument(id: selectedFileDocumentItemId)
        case.share:
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.handleFileDocumentMenuItemSelected(
                    id: selectedFileDocumentItemId,
                    menuItem: menuItem
                )
            }
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
        if selectedMenuItem == .lock && !viewModel.isSelectable {
            tabBar.isTabBarVisible = true
        }
        
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

    let onFolderClick: (UUID) -> Void
    let onDocumentClick: (UUID) -> Void
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
                onFolderClick: onFolderClick,
                onDocumentClick: onDocumentClick,
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
