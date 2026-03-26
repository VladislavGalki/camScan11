import SwiftUI

struct WatermarkView: View {
    @StateObject private var viewModel: WatermarkViewModel
    @State private var shouldShowDeleteConfirmation = false
    @EnvironmentObject private var router: Router

    init(inputModel: WatermarkInputModel) {
        _viewModel = StateObject(wrappedValue: WatermarkViewModel(inputModel: inputModel))
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
            WatermarkStyleSheetView(
                draft: $viewModel.styleDraft,
                placementMode: $viewModel.placementMode,
                onColorChanged: { viewModel.updateSelectedWatermarkStyle(colorHex: $0) },
                onFontSizeChanged: { viewModel.updateSelectedWatermarkStyle(fontSize: $0) },
                onRotationChanged: { viewModel.updateSelectedWatermarkStyle(rotation: $0) },
                onOpacityChanged: { viewModel.updateSelectedWatermarkStyle(opacity: $0) },
                onModeChanged: { viewModel.switchPlacementMode($0) },
                onClose: {}
            )
            .presentationDetents([.height(280)])
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

private extension WatermarkView {
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
            Text("Watermark")
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
            Group {
                if viewModel.placementMode == .single {
                    Text("Tap the screen to place the watermark")
                        .appTextStyle(.bodySecondary)
                        .foregroundStyle(.text(.onHint))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Color.bg(.hintBlue)
                                .appBorderModifier(.border(.hintBlue), radius: 8)
                                .cornerRadius(8, corners: .allCorners)
                        )
                        .opacity(viewModel.watermarkItems.isEmpty ? 1 : 0)
                }
            }
        }
    }

    var carouselView: some View {
        WatermarkCarouselRepresentable(
            models: viewModel.models,
            watermarkItems: viewModel.displayItems,
            selectedWatermarkID: viewModel.selectedWatermarkID,
            editingWatermarkID: viewModel.placementMode == .single ? viewModel.editingWatermarkID : nil,
            editingTextDraft: viewModel.editingTextDraft,
            isScrollDisabled: viewModel.shouldShowStyleSheet,
            delegate: viewModel
        )
    }

    @ViewBuilder
    var bubbleOverlay: some View {
        if let anchor = viewModel.bubbleAnchor,
           viewModel.selectedWatermarkID == anchor.watermarkID,
           viewModel.editingWatermarkID == nil,
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
                    WatermarkActionBubbleView { action in
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
        let isTile = viewModel.placementMode == .tile

        return ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text(isTile ? "Delete all watermarks on this page?" : "Delete the watermark?")

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
                            if isTile {
                                viewModel.deleteAllTileWatermarksOnCurrentPage()
                            } else {
                                viewModel.deleteSelectedWatermark()
                            }
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

private extension WatermarkView {
    func handleBubbleAction(_ action: WatermarkActionType) {
        switch action {
        case .edit:
            if viewModel.placementMode == .single {
                viewModel.startEditingSelectedWatermark()
            }
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
                viewModel.saveWatermarkItems()
                router.pop()
            }
            return
        }

        viewModel.saveWatermarkItems()
        router.pop()
    }
}
