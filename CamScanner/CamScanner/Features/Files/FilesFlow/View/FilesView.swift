import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    
    @State private var shouldShowDotsOverlay = false
    @State private var dotsFrame: CGRect = .zero
    
    @EnvironmentObject private var tabBar: TabBarController
    
    var body: some View {
        contentView
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
                    EmptyView()
                }
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.viewState {
        case .empty:
            emptyView
        case .success:
            successView
                .overlay {
                    dotsOverlayView
                }
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
        GridLayoutView(model: viewModel.items) { documentId, isFavourite in
            viewModel.handleDocumentFavourite(documentId: documentId, isFavourite: isFavourite)
        }
    }
    
    private var listLayoutView: some View {
        ListLayoutView(model: viewModel.items) { documentId, isFavourite in
            viewModel.handleDocumentFavourite(documentId: documentId, isFavourite: isFavourite)
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
                                tabBar.isTabBarVisible.toggle()
                                
                                withAnimation {
                                    shouldShowDotsOverlay = true
                                }
                            }
                        )
                        .reportFrame { frame in
                            dotsFrame = frame
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
    
    private var dotsOverlayView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .opacity(shouldShowDotsOverlay ? 0.12 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(shouldShowDotsOverlay)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        shouldShowDotsOverlay = false
                        tabBar.isTabBarVisible = true
                    }
                }

            if shouldShowDotsOverlay {
                dotsMenu
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .topTrailing)
                            .combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
    
    private var dotsMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                meuDotRow(title: "New folder", icon: .folder) {
                    shouldShowDotsOverlay = false
                    tabBar.isTabBarVisible = true
                    viewModel.fileActiveSheet = .createFolder
                }
                
                meuDotRow(title: "Select files", icon: .check_circle) {
                    shouldShowDotsOverlay = false
                    tabBar.isTabBarVisible = true
                }
                
                dividerView
                    .padding(.vertical, 8)
                
                sectionTitle("Sort by")
                
                ForEach(FilesSortType.allCases) { type in
                    dotsSelectableRow(
                        title: type.title,
                        leftIcon: nil,
                        isSelected: viewModel.sortType == type,
                        action: {
                            shouldShowDotsOverlay = false
                            tabBar.isTabBarVisible = true
                            viewModel.handleFilesSortType(type: type)
                        }
                    )
                }
                
                dividerView
                    .padding(.vertical, 8)
                
                sectionTitle("View by")
                
                ForEach(FilesViewMode.allCases) { mode in
                    dotsSelectableRow(
                        title: mode.title,
                        leftIcon: imageByViewMode(mode: mode),
                        isSelected: viewModel.viewMode == mode
                    ) {
                        shouldShowDotsOverlay = false
                        tabBar.isTabBarVisible = true
                        viewModel.viewMode = mode
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(width: 200)
        .background(Color.bg(.surface))
        .cornerRadius(24)
        .appBorderModifier(.border(.primary), radius: 24)
        .shadow(color: .black.opacity(0.05), radius: 30)
        .padding(.trailing, 16)
        .offset(y: dotsFrame.maxY + 64)
        .animation(nil, value: viewModel.sortType)
        .animation(nil, value: viewModel.viewMode)
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text("Sort by")
            .appTextStyle(.meta)
            .foregroundStyle(.text(.secondary))
            .padding(.vertical, 8)
    }
    
    private func meuDotRow(title: String, icon: AppIcon, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(appIcon: icon)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.elements(.primary))
                .frame(width: 18, height: 18)
            
            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
    
    private func dotsSelectableRow(title: String, leftIcon: Image?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            if let leftIcon {
                leftIcon
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.primary))
                    .frame(width: 18, height: 18)
            }
            
            Text(title)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.primary))
            
            Spacer(minLength: 0)
            
            if isSelected {
                Image(appIcon: .check)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.elements(.accent))
                    .frame(width: 18, height: 18)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
    
    private func imageByViewMode(mode: FilesViewMode) -> Image {
        switch mode {
        case .grid:
            return Image(appIcon: .grid2)
        case .list:
            return Image(appIcon: .list)
        }
    }
    
    private var dividerView: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .foregroundStyle(.divider(.default))
            .frame(height: 1)
    }
}
