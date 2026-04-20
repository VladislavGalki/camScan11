import SwiftUI

struct AddTextView: View {
    @StateObject private var viewModel: AddTextViewModel
    @State private var shouldShowDeleteConfirmation = false
    @EnvironmentObject private var router: Router

    init(inputModel: AddTextInputModel, dependencies: AppDependencies) {
        _viewModel = StateObject(wrappedValue: AddTextViewModel(
            inputModel: inputModel,
            dependencies: dependencies
        ))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                navigationBar
                    .padding(.bottom, 16)

                pageIndicator
                    .padding(.bottom, 51)

                carouselView
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 187)
                    .allowsHitTesting(!viewModel.shouldShowStyleSheet)
                    .ignoresSafeArea(.keyboard, edges: .all)
            }

            bubbleOverlay
                .opacity(viewModel.shouldShowStyleSheet ? 0 : 1)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.bg(.main).ignoresSafeArea())
        .sheet(isPresented: $viewModel.shouldShowStyleSheet) {
            viewModel.shouldShowStyleSheet = false
        } content: {
            AddTextStyleSheetView(
                draft: $viewModel.styleDraft,
                onColorChanged: { viewModel.updateSelectedTextStyle(colorHex: $0) },
                onFontSizeChanged: { viewModel.updateSelectedTextStyle(fontSize: $0) },
                onRotationChanged: { viewModel.updateSelectedTextStyle(rotation: $0) },
                onClose: {}
            )
            .presentationDetents([.height(163)])
            .presentationBackgroundInteraction(.enabled)
            .presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
        }
        .overlay {
            if shouldShowDeleteConfirmation {
                deleteConfirmationOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension AddTextView {
    var navigationBar: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.arrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: { router.pop() }
            )

            Spacer(minLength: 0)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: { saveAndDismiss() }
            )
            .appButtonEnabled(viewModel.isSaveEnabled && !viewModel.isEditingText)
        }
        .overlay {
            Text("Add text")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), radius: 0)
                .ignoresSafeArea(edges: .top)
        )
    }

    var pageIndicator: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.selectedIndex + 1)/\(viewModel.models.count)")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.onOverlay))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .foregroundStyle(.bg(.overlay))
                )
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Text("Tap the screen to place the text")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.onHint))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Color.bg(.hintBlue)
                        .appBorderModifier(.border(.hintBlue), radius: 8)
                        .cornerRadius(8, corners: .allCorners)
                )
                .opacity(viewModel.textItems.isEmpty ? 1 : 0)
        }
    }

    var carouselView: some View {
        AddTextCarouselRepresentable(
            models: viewModel.models,
            textItems: viewModel.textItems,
            selectedTextID: viewModel.selectedTextID,
            editingTextID: viewModel.editingTextID,
            editingTextDraft: viewModel.editingTextDraft,
            delegate: viewModel
        )
    }

    @ViewBuilder
    var bubbleOverlay: some View {
        if let anchor = viewModel.bubbleAnchor,
           viewModel.selectedTextID == anchor.textID,
           viewModel.editingTextID == nil,
           !viewModel.shouldShowStyleSheet {
            GeometryReader { geo in
                let bubbleSize = CGSize(width: 280, height: 64)
                let horizontalPadding: CGFloat = 8
                let spacing: CGFloat = 16
                let rect = anchor.rect

                let x = min(
                    max(rect.midX - bubbleSize.width / 2, horizontalPadding),
                    geo.size.width - bubbleSize.width - horizontalPadding
                )
                let y = rect.minY - bubbleSize.height - spacing

                let bubbleFrame = CGRect(x: x, y: y, width: bubbleSize.width, height: bubbleSize.height)

                BubbleOverlayHost(frame: bubbleFrame) {
                    AddTextActionBubbleView { action in
                        handleBubbleAction(action)
                    }
                    .frame(width: bubbleSize.width, height: bubbleSize.height)
                }
                .ignoresSafeArea()
                .zIndex(1000)
            }
        }
    }

    var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text("Delete the text?")

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Delete"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            viewModel.deleteSelectedText()
                            shouldShowDeleteConfirmation = false
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: { shouldShowDeleteConfirmation = false }
                    )
                }
            }
            .padding(16)
            .frame(width: 300)
            .background(
                Color.bg(.surface)
                    .cornerRadius(24, corners: .allCorners)
            )
        }
    }
}

// MARK: - Actions

private extension AddTextView {
    func handleBubbleAction(_ action: AddTextActionType) {
        switch action {
        case .edit:
            viewModel.startEditingSelectedText()
        case .style:
            viewModel.openStyleEditor()
        case .delete:
            shouldShowDeleteConfirmation = true
        }
    }

    func saveAndDismiss() {
        if viewModel.shouldShowStyleSheet {
            viewModel.shouldShowStyleSheet = false
            Task {
                try? await Task.sleep(for: .seconds(0.10))
                viewModel.saveTextItems()
                router.pop()
            }
            return
        }

        viewModel.saveTextItems()
        router.pop()
    }
}
