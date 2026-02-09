import SwiftUI
import UIKit

struct ScanPreviewView: View {
    @State private var actionBottomBarAction: ScanPreviewBottomBarAction?
    @State private var sliderValue: Double = 0.5
    @State private var shoudShowDeleteOverlay: Bool = false
    
    @StateObject private var viewModel: ScanPreviewViewModel
    @EnvironmentObject private var router: Router
    
    init(inputModel: ScanPreviewInputModel) {
        _viewModel = StateObject(wrappedValue: ScanPreviewViewModel(inputModel: inputModel))
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
            if shoudShowDeleteOverlay {
                overlayDeleteView
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(
            Color.bg(.main).ignoresSafeArea()
        )
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
                    router.pop()
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
                    action: {}
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Done"),
                        style: .primary,
                        size: .m
                    ),
                    action: {}
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
            
            AppSlider(value: $sliderValue, range: 0...1)
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
            tabItemView(icon: .page_plus, title: "Add page")
                .onTapGesture {
                    router.pop()
                }
            
            tabItemView(icon: .crop, title: "Crop")
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
                        shoudShowDeleteOverlay = true
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
    
    private var overlayDeleteView: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            
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
                            extraTitleColor: .text(.distructive),
                            isFullWidth: true
                        ),
                        action: {
                            shoudShowDeleteOverlay = false
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
                            shoudShowDeleteOverlay = false
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
                            shoudShowDeleteOverlay = false
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
}
