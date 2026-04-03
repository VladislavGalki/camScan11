import SwiftUI

struct OpenDocumentSelectPagesMoveView: View {
    @StateObject private var viewModel: OpenDocumentSelectPagesMoveViewModel
    @State private var shouldShowPinOverlay = false
    @State private var shouldShowFolderCreationSheet = false

    let onComplete: (OpenDocumentSelectPagesMoveResult) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        inputModel: OpenDocumentSelectPagesMoveInputModel,
        onComplete: @escaping (OpenDocumentSelectPagesMoveResult) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: OpenDocumentSelectPagesMoveViewModel(inputModel: inputModel)
        )
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            listView
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            navigationView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg(.main))
        .overlay { pinOverlay }
        .sheet(isPresented: $shouldShowFolderCreationSheet) {
            CreateFolderView { folderName in
                viewModel.handleFolderCreated(folderName: folderName)
            }
            .presentationCornerRadius(38)
        }
    }
}

private extension OpenDocumentSelectPagesMoveView {
    var navigationView: some View {
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
                    let result = viewModel.moveSelectedPages()
                    if case .failed = result {
                        return
                    }
                    onComplete(result)
                    dismiss()
                }
            )
            .appButtonEnabled(viewModel.canConfirmMove)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ProgressiveBlurView()
                .blur(radius: 20)
                .background {
                    LinearGradient(
                        colors: [
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 1),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0.5),
                            Color(red: 247/255, green: 247/255, blue: 247/255, opacity: 0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    var navigationFolderItemView: some View {
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
                if viewModel.currentFolderID != nil {
                    viewModel.goBackTapped()
                } else {
                    shouldShowFolderCreationSheet = true
                }
            }

            Rectangle()
                .foregroundStyle(.divider(.default))
                .frame(height: 1)
                .cornerRadius(2, corners: .allCorners)
        }
    }

    var listView: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.items.indices, id: \.self) { index in
                    switch viewModel.items[index] {
                    case let .folder(folder):
                        ListFolderRow(
                            item: folder,
                            highlightedID: nil,
                            shouldHideAllSettings: true,
                            shouldHideSettings: true,
                            onMenuClick: { _, _ in }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.openFolderTapped(folder.id)
                        }
                    case let .document(document):
                        OpenDocumentMoveSelectableRow(
                            item: document,
                            isSelected: viewModel.selectedTargetDocumentID == document.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                switch await viewModel.handleDocumentTap(document.id) {
                                case .authorized:
                                    break
                                case .requiresPin:
                                    shouldShowPinOverlay = true
                                case .failed:
                                    break
                                }
                            }
                        }
                    }

                    if index < viewModel.items.count - 1 {
                        RoundedRectangle(cornerRadius: 2)
                            .foregroundStyle(.divider(.default))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 7)
            .padding(.horizontal, 16)
            .padding(.bottom, Constants.tabBarHeight)
        }
    }

    @ViewBuilder
    var pinOverlay: some View {
        if shouldShowPinOverlay {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()

                EnterPinView(
                    documentTitle: viewModel.pendingLockedDocumentTitle,
                    validatePin: { pin in
                        viewModel.validatePendingDocumentPin(pin)
                    },
                    onSuccess: {
                        shouldShowPinOverlay = false
                        viewModel.completePendingPinAuthorization()
                    },
                    onClose: {
                        shouldShowPinOverlay = false
                        viewModel.cancelPendingPinAuthorization()
                    }
                )
            }
        }
    }
}

private struct OpenDocumentMoveSelectableRow: View {
    let item: FileDocumentItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ListDocumentBackground(item: item)
                .frame(width: 35.33, height: 50)
                .appBorderModifier(.border(.primary), radius: 4)
                .overlay {
                    ListDocumentPreview(item: item)
                }
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .appTextStyle(.bodySecondary)
                    .foregroundStyle(.text(.primary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.pageCount) \(item.pageCount > 1 ? "Pages" : "Page")")
                    .appTextStyle(.helperText)
                    .foregroundStyle(.text(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)

            Spacer()

            if isSelected {
                Image(appIcon: .check)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.accent))
            }
        }
        .padding(.vertical, 9)
    }
}
