import SwiftUI

struct OpenDocumentView: View {
    @StateObject private var viewModel: OpenDocumentViewModel
    @State private var bottomBarAction: ScanPreviewBottomBarAction?

    @EnvironmentObject private var router: Router
    
    @Environment(\.dismiss) private var dismiss

    init(inputModel: OpenDocumentInputModel) {
        _viewModel = StateObject(
            wrappedValue: OpenDocumentViewModel(inputModel: inputModel)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.bottom, 37)

            carouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 37)

            filtersView

            bottomBarView
        }
        .navigationBarBackButtonHidden(true)
        .background(
            Color.bg(.main).ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard, edges: .all)
        .overlay {
            if viewModel.isExtractingText {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .transaction { $0.animation = nil }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isExtractingText {
                extractingOverlay
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.isExtractingText)
        .sheet(isPresented: Binding(
            get: { viewModel.extractedText != nil },
            set: { if !$0 { viewModel.extractedText = nil } }
        )) {
            ExtractTextSheetView(
                text: Binding(
                    get: { viewModel.extractedText ?? "" },
                    set: { viewModel.extractedText = $0 }
                ),
                documentName: viewModel.title,
                onDismiss: { viewModel.extractedText = nil }
            )
            .presentationDetents([.large])
            .presentationCornerRadius(38)
            .presentationDragIndicator(.hidden)
        }
        .onAppear {
            viewModel.reloadTextItems()
        }
    }
}

private extension OpenDocumentView {
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.strokeArrowBack),
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
                .underline(true, color: .text(.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .onTapGesture { }

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.dots),
                    style: .secondary,
                    size: .m
                ),
                action: { }
            )

            AppButton(
                config: AppButtonConfig(
                    content: .title("Share"),
                    style: .primary,
                    size: .m
                ),
                action: {
                    router.presentSheet(
                        OpenDocumentRoute.share(
                            viewModel.makeShareInputModel()
                        )
                    )
                }
            )
        }
        .padding(.bottom, 10)
        .padding(.horizontal, 16)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
                .ignoresSafeArea(edges: .top)
        )
    }
    
    var carouselView: some View {
        OpenDocumentCarouselRepresentable(
            models: viewModel.models,
            textItems: viewModel.textItems,
            actionBottomBarAction: $bottomBarAction,
            onPageChanged: { index in
                viewModel.updateSelectedIndex(index)
            },
            onRotatePage: { index in
                viewModel.rotatePage(at: index)
            },
            onCellHeightChanged: { height in
                viewModel.updateCellHeight(height)
            }
        )
    }
    
    private var filtersView: some View {
        VStack(spacing: 16) {
            FilterCarouselView(
                model: viewModel.filterPreviewItems,
                onFilterSelected: { filter in
                    viewModel.applyFilter(filter)
                }
            )

            AppSlider(value: $viewModel.sliderValue, range: viewModel.currentFilterType.sliderRange)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            viewModel.previewSliderValue(viewModel.sliderValue)
                        }
                        .onEnded { _ in
                            viewModel.commitSliderValue(viewModel.sliderValue)
                        }
                )
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(height: 132)
        .background(
            Color.bg(.surface)
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.back),
                        style: .secondary,
                        size: .s
                    ),
                    action: { viewModel.undoFilter() }
                )
                .appButtonEnabled(viewModel.shouldEnableUndoButton)

                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.forward),
                        style: .secondary,
                        size: .s
                    ),
                    action: { viewModel.redoFilter() }
                )
                .appButtonEnabled(viewModel.shouldEnableRedoButton)
            }
            .padding(.horizontal, 16)
            .offset(y: -44)
            .opacity(viewModel.shouldShowFilterStateButton ? 1 : 0)
        }
        .overlay(alignment: .topTrailing) {
            AppButton(
                config: AppButtonConfig(
                    content: .title("Apply to all pages"),
                    style: .secondary,
                    size: .s
                ),
                action: { viewModel.applyFilterToAllPages() }
            )
            .padding(.horizontal, 16)
            .offset(y: -44)
            .opacity(viewModel.shouldShowFilterStateButton ? 1 : 0)
        }
        .disabled(viewModel.filterPreviewItems.contains { !$0.isEnabled })
    }
    
    var bottomBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(OpenDocumentBottomBarActionType.allCases) { item in
                    bottomItem(item)
                        .onTapGesture {
                            handleBottomBarTap(item)
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    func bottomItem(_ item: OpenDocumentBottomBarActionType) -> some View {
        VStack(spacing: 4) {
            Image(appIcon: item.icon)
                .renderingMode(.template)
                .foregroundStyle(
                    item.isDestructive
                    ? .elements(.destructive)
                    : .elements(.secondary)
                )

            Text(item.title)
                .appTextStyle(.tabBar)
                .foregroundStyle(
                    item.isDestructive
                    ? .text(.destructive)
                    : .text(.secondary)
                )
        }
        .frame(width: 70, height: 54)
        .contentShape(Rectangle())
    }
    
    var extractingOverlay: some View {
        VStack(spacing: 0) {
            ExtractSpinnerView()
                .padding(.top, 45)
                .padding(.bottom, 24)

            Text("Recognizing text")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)

            Text("You’ll get editable text that you can easily share")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: 227)
        .background(
            Color.bg(.surface)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func handleBottomBarTap(_ action: OpenDocumentBottomBarActionType) {
        switch action {
        case .crop:
            router.push(
                OpenDocumentRoute.scanCropper(
                    viewModel.makeCropperInputModel(),
                    onFinish: { outputModel in
                        viewModel.applyCropOutput(outputModel)
                    }
                )
            )
        case .rotate:
            bottomBarAction = .rotate
        case .addPage:
            router.present(
                OpenDocumentRoute.scanFlow(
                    ScanInputModel(existingDocumentID: viewModel.documentId),
                    onDismiss: {
                        viewModel.reloadTextItems()
                    }
                )
            )
        case .addText:
            router.push(
                OpenDocumentRoute.addText(
                    AddTextInputModel(documentID: viewModel.documentId)
                )
            )
        case .signature:
            break
        case .erase:
            break
        case .watermark:
            break
        case .extract:
            viewModel.extractText()
        case .translate:
            break
        case .delete:
            break
        }
    }
}
