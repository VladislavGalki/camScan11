import SwiftUI

struct MoveDocumentsView: View {
    @StateObject private var viewModel: MoveDocumentsViewModel
    
    @State private var shouldShowFolderCreationSheet: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        inputModel: MoveDocumentInputModel,
        onMove: @escaping ([UUID], UUID?) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: MoveDocumentsViewModel(
            viewMode: inputModel.viewMode,
            folderId: inputModel.folderId,
            documentIDs: inputModel.documentIDs,
            onMove: onMove)
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding([.bottom, .horizontal], 16)
            
            navigationFolderItemView
                .padding(.bottom, 9)
                .padding(.horizontal, 16)
            
            listView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.bg(.main)
        )
        .sheet(isPresented: $shouldShowFolderCreationSheet) {
            CreateFolderView { folderName in
                viewModel.handleFolderCreated(folderName: folderName)
            }
            .presentationCornerRadius(38)
        }
    }
    
    private var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.close),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    dismiss()
                }
            )
            
            Text(viewModel.title)
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    viewModel.handleMoveAction()
                }
            )
        }
        .padding(.vertical, 12)
        .background(
            Color.bg(.main)
        )
    }
    
    @ViewBuilder
    private var navigationFolderItemView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(appIcon: viewModel.currentFolderID != nil ? .arrowBack : .folder)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
                
                Text(viewModel.currentFolderID != nil ? "Back to files" : "New folder")
                    .appTextStyle(.bodyPrimary)
                    .foregroundStyle(.text(.accent))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 9)
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel .currentFolderID != nil {
                    viewModel.goBackTapped()
                    return
                }
                
                shouldShowFolderCreationSheet = true
            }
            
            Rectangle()
                .foregroundStyle(.divider(.default))
                .frame(height: 1)
                .cornerRadius(2, corners: .allCorners)
        }
    }
    
    private var listView: some View {
        FilesLayoutContainer(
            mode: viewModel.viewMode,
            items: viewModel.items,
            shouldHideAllSettings: true,
            onFolderClick: { id in
                viewModel.openFolderTapped(id)
            },
            onDocumentClick: { _ in },
            onFavourite: { _, _ in},
            onMenuClick: { _, _ in }
        )
    }
}
