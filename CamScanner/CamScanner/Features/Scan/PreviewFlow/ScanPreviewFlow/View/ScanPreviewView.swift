import SwiftUI
import UIKit

struct ScanPreviewView: View {
    @State private var actionBottomBarAction: ScanPreviewBottomBarAction?
    
    @StateObject private var viewModel: ScanPreviewViewModel
    @EnvironmentObject private var router: Router
    
    init(
        inputModel: ScanPreviewInputModel,
        onFinish: @escaping (ScanPreviewInputModel) -> Void,
        onSuccessFlow: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ScanPreviewViewModel(inputModel: inputModel, onFinish: onFinish, onSuccessFlow: onSuccessFlow)
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.bottom, 37)
            
            documentCarouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 37)
            
            filtersView
            
            bottomContainerView
        }
        .overlay {
            notificationView
        }
        .navigationBarBackButtonHidden(true)
        .background(
            Color.bg(.main).ignoresSafeArea()
        )
        .ignoresSafeArea(.keyboard, edges: .all)
    }
    
    private var navigationView: some View {
        HStack(spacing: 0) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.strokeArrowBack),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    withAnimation {
                        viewModel.notificationState = .back
                    }
                }
            )
            
            Spacer(minLength: 0)
            
            HStack(spacing: 8) {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.share),
                        style: .secondary,
                        size: .m
                    ),
                    action: {
                        router.presentSheet(
                            ScanRoute.share(
                                ShareInputModel(
                                    documentName: viewModel.documentFileName,
                                    documentType: viewModel.documentType,
                                    pages: viewModel.scanPreviewModel
                                )
                            )
                        )
                    }
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Done"),
                        style: .primary,
                        size: .m
                    ),
                    action: {
                        do {
                            try viewModel.saveDocument()
                        } catch {
                            // Мб вьюху с ошибкой
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
                .ignoresSafeArea(edges: .top)
        )
    }
    
    private var documentCarouselView: some View {
        PreviewCarouselRepresentable(
            models: viewModel.scanPreviewModel,
            actionBottomBarAction: $actionBottomBarAction,
            onPageChanged: { index in
                viewModel.updateSelectedPageIndex(index)
            },
            onRotatePage: { pageIndex in
                viewModel.rotatePage(at: pageIndex)
            },
            onAddTapped: {
                viewModel.onFinishFlow(viewModel.buildOutputModel())
                router.pop()
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
                .appButtonEnabled(viewModel.shouldDisableUndoButton)
                
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.forward),
                        style: .secondary,
                        size: .s
                    ),
                    action:  { viewModel.redoFilter() }
                )
                .appButtonEnabled(viewModel.shouldDisableRedoButton)
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
        .disabled(viewModel.filterPreviewItems.contains { $0.isEnabled == false })
    }
    
    private var bottomContainerView: some View {
        HStack(spacing: 0) {
            if viewModel.documentType != .idCard && viewModel.documentType != .driverLicense {
                tabItemView(icon: .page_plus, title: "Add page")
                    .onTapGesture {
                        viewModel.onFinishFlow(viewModel.buildOutputModel())
                        router.pop()
                    }
            }
            
            tabItemView(icon: .crop, title: "Crop")
                .onTapGesture {
                    router.push(
                        ScanRoute.scanCropper(
                            viewModel.makeCropperInputModel(),
                            onFinish: { outputModel in
                                viewModel.applyCropOutput(outputModel)
                            }
                        )
                    )
                }
            tabItemView(icon: .rotate, title: "Rotate")
                .onTapGesture {
                    actionBottomBarAction = .rotate
                    
                    DispatchQueue.main.async {
                        actionBottomBarAction = nil
                    }
                }
            tabItemView(icon: .signature, title: "Signature")
            tabItemView(icon: .trash, title: "Delete")
                .onTapGesture {
                    withAnimation {
                        viewModel.notificationState = .delete
                    }
                }
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private func tabItemView(icon: AppIcon, title: String) -> some View {
        VStack(spacing: 4) {
            Image(appIcon: icon)
                .renderingMode(.template)
                .foregroundStyle(.elements(.navigationDefault))
            
            Text(title)
                .appTextStyle(.tabBar)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
    }
    
    @ViewBuilder
    private var notificationView: some View {
        if viewModel.notificationState != .none {
            ZStack {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                
                switch viewModel.notificationState {
                case .back:
                    discardOverlay
                case .delete:
                    overlayDeleteView
                case .none:
                    EmptyView()
                }
            }
        }
    }
    
    private var discardOverlay: some View {
        VStack(spacing: 0) {
            Text("Start Over?")
                .multilineTextAlignment(.center)
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)
            
            Text("Your current scans will be deleted.")
                .multilineTextAlignment(.center)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .padding(.bottom, 24)
            
            VStack(spacing: 10) {
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Start over"),
                        style: .primary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        viewModel.notificationState = .none
                        viewModel.onFinishFlow(viewModel.buildOutputClearModel())
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
                    action: {
                        viewModel.notificationState = .none
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .foregroundStyle(.bg(.surface))
        )
        .frame(maxWidth: 300)
    }
    
    private var overlayDeleteView: some View {
        VStack(spacing: 0) {
            Text("Delete the page?")
                .multilineTextAlignment(.center)
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 8)
            
            Text("You can retake it instead.")
                .multilineTextAlignment(.center)
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .padding(.bottom, 24)
            
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
                        viewModel.notificationState = .none
                        if let pageIndex = viewModel.deletePage() {
                            actionBottomBarAction = .deletePage(pageIndex)
                            
                            DispatchQueue.main.async {
                                actionBottomBarAction = nil
                            }
                        }
                    }
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Retake"),
                        style: .secondary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        viewModel.notificationState = .none
                        if let _ = viewModel.deletePage() {
                            viewModel.onFinishFlow(viewModel.buildOutputModel())
                            router.pop()
                        }
                    }
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Cancel"),
                        style: .secondary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        viewModel.notificationState = .none
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .foregroundStyle(.bg(.surface))
        )
        .frame(maxWidth: 300)
    }
}
