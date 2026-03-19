import SwiftUI

struct AddTextView: View {
    @StateObject private var viewModel: AddTextViewModel

    @EnvironmentObject private var router: Router

    init(inputModel: AddTextInputModel) {
        _viewModel = StateObject(
            wrappedValue: AddTextViewModel(inputModel: inputModel)
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                navigationView
                    .padding(.bottom, 16)

                placeholderView
                    .padding(.bottom, 51)

                carouselView
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, 187)
                    .ignoresSafeArea(.keyboard, edges: .all)
            }

            bubbleOverlay
        }
        .navigationBarBackButtonHidden(true)
        .background(
            Color.bg(.main).ignoresSafeArea()
        )
    }
}

// MARK: - Subviews

private extension AddTextView {
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.arrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    router.pop()
                }
            )

            Spacer(minLength: 0)

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    viewModel.saveTextItems()
                    router.pop()
                }
            )
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

    var placeholderView: some View {
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
    }

    var carouselView: some View {
        AddTextCarouselRepresentable(
            models: viewModel.models,
            textItems: viewModel.textItems,
            selectedTextID: viewModel.selectedTextID,
            editingTextID: viewModel.editingTextID,
            editingTextDraft: viewModel.editingTextDraft,
            onPageChanged: { index in
                viewModel.updateSelectedIndex(index)
            },
            onPageTap: { pageIndex, point, initialSize in
                viewModel.handlePageTap(
                    pageIndex: pageIndex,
                    location: point,
                    initialSize: initialSize
                )
            },
            onTextTap: { id in
                viewModel.selectText(id)
            },
            onSelectedTextFrameChanged: { id, rect in
                guard viewModel.selectedTextID == id, let rect else { return }
                guard !viewModel.shouldFreezeBubbleAnchor else { return }

                let newAnchor = AddTextBubbleAnchor(
                    textID: id,
                    pageIndex: viewModel.selectedIndex,
                    rect: rect
                )

                guard viewModel.bubbleAnchor != newAnchor else { return }
                
                Task { @MainActor in
                    viewModel.updateBubbleAnchor(newAnchor)
                }
            },
            onTextMove: { id, center in
                viewModel.moveText(id: id, to: center)
            },
            onTextResize: { id, width, centerX, size in
                viewModel.resizeText(id: id, width: width, centerX: centerX, pageSize: size)
            },
            onPageSizeChanged: { size in
                viewModel.updateCurrentPageSize(size)
            },
            onResizeStateChanged: { isResizing in
                viewModel.setBubbleAnchorFrozen(isResizing)
            },
            onEditingTextChanged: { text, pageSize in
                Task { @MainActor in
                    viewModel.updateEditingDraft(text, pageSize: pageSize)
                }
            },
            onEditingSubmit: {
                viewModel.applyTextEditing()
            },
            onScrollStarted: {
                viewModel.clearSelection()
            }
        )
    }

    @ViewBuilder
    private var bubbleOverlay: some View {
        if let anchor = viewModel.bubbleAnchor,
           viewModel.selectedTextID == anchor.textID,
           viewModel.editingTextID == nil {
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

                let bubbleFrame = CGRect(
                    x: x,
                    y: y,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )

                BubbleOverlayHost(frame: bubbleFrame) {
                    AddTextActionBubbleView { action in
                        handleAction(action)
                    }
                    .frame(width: bubbleSize.width, height: bubbleSize.height)
                }
                .ignoresSafeArea()
                .zIndex(1000)
            }
        }
    }
}

// MARK: - Actions

private extension AddTextView {
    func handleAction(_ action: AddTextActionType) {
        switch action {
        case .edit:
            viewModel.startEditingSelectedText()
        case .style:
            viewModel.openStyleStub()
        case .delete:
            viewModel.deleteSelectedText()
        }
    }
}
