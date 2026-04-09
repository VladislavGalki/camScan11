import SwiftUI

struct PlaceSignatureView: View {
    @StateObject private var viewModel: PlaceSignatureViewModel
    @State private var shouldShowDeleteConfirmation = false
    @State private var shouldShowExitConfirmation = false
    @EnvironmentObject private var router: Router

    init(inputModel: PlaceSignatureInputModel) {
        _viewModel = StateObject(wrappedValue: PlaceSignatureViewModel(inputModel: inputModel))
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
            }

            bubbleOverlay
                .opacity(viewModel.shouldShowStyleSheet ? 0 : 1)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.bg(.main).ignoresSafeArea())
        .sheet(
            isPresented: $viewModel.shouldShowStyleSheet,
            onDismiss: {
                viewModel.shouldShowStyleSheet = false
            }
        ) {
            SignatureStyleSheetView(
                initialColorHex: viewModel.styleDraftColorHex,
                initialThickness: viewModel.styleDraftThickness,
                onColorChanged: { viewModel.updateSignatureStyle(colorHex: $0) },
                onThicknessChanged: { viewModel.updateSignatureStyle(thickness: $0) }
            )
            .id(viewModel.selectedSignatureID)
            .presentationDetents([.height(160)])
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
        .overlay {
            if shouldShowExitConfirmation {
                exitConfirmationOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension PlaceSignatureView {
    var navigationBar: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.arrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    if viewModel.hasChanges {
                        shouldShowExitConfirmation = true
                    } else {
                        router.pop()
                    }
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
                    // Stub: just close the screen
                    router.pop()
                }
            )
            .appButtonEnabled(viewModel.isSaveEnabled)
        }
        .overlay {
            Text("Signature")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
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
    }

    var carouselView: some View {
        SignatureCarouselRepresentable(
            models: viewModel.models,
            signatureItems: viewModel.signatureItems,
            selectedSignatureID: viewModel.selectedSignatureID,
            isScrollDisabled: viewModel.shouldShowStyleSheet,
            isInteractionDisabled: viewModel.shouldShowStyleSheet,
            delegate: viewModel
        )
    }

    @ViewBuilder
    var bubbleOverlay: some View {
        if let anchor = viewModel.bubbleAnchor,
           viewModel.selectedSignatureID == anchor.signatureID,
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
                    SignatureActionBubbleView(
                        isEditEnabled: viewModel.selectedSignatureHasStrokes
                    ) { action in
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
                Text("Delete the signature?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))

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
                            viewModel.deleteSelectedSignature()
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

    var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .transaction { $0.animation = nil }

            VStack(spacing: 24) {
                Text("Discard unsaved changes?")
                    .multilineTextAlignment(.center)
                    .appTextStyle(.itemTitle)
                    .foregroundStyle(.text(.primary))

                VStack(spacing: 10) {
                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Discard"),
                            style: .secondary,
                            size: .l,
                            extraTitleColor: .text(.destructive),
                            isFullWidth: true
                        ),
                        action: {
                            shouldShowExitConfirmation = false
                            router.pop()
                        }
                    )

                    AppButton(
                        config: AppButtonConfig(
                            content: .title("Cancel"),
                            style: .secondary,
                            size: .l,
                            isFullWidth: true
                        ),
                        action: { shouldShowExitConfirmation = false }
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

private extension PlaceSignatureView {
    func handleBubbleAction(_ action: SignatureActionType) {
        switch action {
        case .delete:
            shouldShowDeleteConfirmation = true
        case .duplicate:
            viewModel.duplicateSelectedSignature()
        case .edit:
            viewModel.openStyleEditor()
        }
    }
}
