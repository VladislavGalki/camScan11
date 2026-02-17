import SwiftUI

struct ScanCropperView: View {
    @StateObject private var viewModel: ScanCropperViewModel
    
    @EnvironmentObject private var router: Router
    
    init(
        input: ScanCropperInputModel,
        onFinish: @escaping (ScanPreviewInputModel) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ScanCropperViewModel(input: input, onFinish: onFinish))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.bottom, 16)
            
            pageIndicatorView
                .padding(.horizontal, 16)
                .padding(.bottom, 51)
            
            cropperCarouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 73)
            
            historyStateView
                .padding([.horizontal, .bottom], 16)
            
            bottomContainerView
        }
        .navigationBarBackButtonHidden(true)
        .overlay {
            notificationView
        }
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
                    withAnimation {
                        viewModel.notificationState = .discardChanges
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
                    viewModel.finishFlow()
                    router.pop()
                }
            )
        }
        .overlay {
            Text("Crop")
                .appTextStyle(.topBarTitle)
                .foregroundStyle(.text(.primary))
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
    
    private var pageIndicatorView: some View {
        HStack(spacing: 0) {
            Text("\(viewModel.selectedIndex + 1)/\(viewModel.pages.count)")
                .appTextStyle(.bodySecondary)
                .foregroundStyle(.text(.onOverlay))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .foregroundStyle(.bg(.overlay))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var cropperCarouselView: some View {
        CropperCarouselRepresentable(
            models: viewModel.pages,
            onPageChanged: { index in
                viewModel.selectPage(index)
            },
            onQuadChanged: { index, quad in
                viewModel.setChangedQuad(index: index, quad: quad)
            }
        )
    }
    
    private var historyStateView: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.back),
                        style: .secondary,
                        size: .s
                    ),
                    action: { viewModel.undoQuad() }
                )
                .appButtonEnabled(viewModel.canUndoQuad)
                
                AppButton(
                    config: AppButtonConfig(
                        content: .iconOnly(.forward),
                        style: .secondary,
                        size: .s
                    ),
                    action:  { viewModel.redoQuad() }
                )
                .appButtonEnabled(viewModel.canRedoQuad)
            }
            
            Spacer(minLength: 0)
            
            AppButton(
                config: AppButtonConfig(
                    content: .title("Apply to all pages"),
                    style: .secondary,
                    size: .s
                ),
                action: {
                    withAnimation {
                        viewModel.notificationState = .applyToAllPages
                    }
                }
            )
            .opacity(viewModel.shouldShowApplyToAllButton ? 1 : 0)
        }
        .opacity(viewModel.canUndoQuad || viewModel.canRedoQuad ? 1 : 0)
    }
    
    private var bottomContainerView: some View {
        HStack(spacing: 0) {
            tabItemView(icon: .autoCrop, type: .autoCrop, title: "Auto Crop")
                .onTapGesture {
                    viewModel.setAutoQuad()
                }
            tabItemView(icon: .expand, type: .expand, title: "Expand")
                .onTapGesture {
                    viewModel.setFullQuad()
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
    
    @ViewBuilder
    private func tabItemView(icon: AppIcon, type: CropSelectedType, title: String) -> some View {
        let isSelected = viewModel.cropSelectedType == type

        VStack(spacing: 4) {
            Image(appIcon: icon)
                .renderingMode(.template)
                .foregroundStyle(
                    isSelected
                    ? .elements(.secondary)
                    : .elements(.disabled)
                )

            Text(title)
                .appTextStyle(.tabBar)
                .foregroundStyle(
                    isSelected
                    ? .text(.secondary)
                    : .text(.disabled)
                )
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
                case .discardChanges:
                    discardChangesView
                case .applyToAllPages:
                    applyChangesView
                case .none:
                    EmptyView()
                }
            }
        }
    }
    
    private var discardChangesView: some View {
        VStack(spacing: 0) {
            Text("Discard changes?")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            
            Text("Your edits haven’t been saved.")
                .appTextStyle(.bodyPrimary)
                .foregroundStyle(.text(.secondary))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            
            VStack(spacing: 10) {
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Keep Editing"),
                        style: .primary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        withAnimation {
                            viewModel.notificationState = .none
                        }
                    }
                )
                
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Discard Changes"),
                        style: .secondary,
                        size: .l,
                        extraTitleColor: .text(.distructive),
                        isFullWidth: true
                    ),
                    action: {
                        viewModel.notificationState = .none
                        router.pop()
                    }
                )
            }
        }
        .padding(16)
        .background(.bg(.surface))
        .cornerRadius(24, corners: .allCorners)
        .frame(maxWidth: 300)
    }
    
    private var applyChangesView: some View {
        VStack(spacing: 0) {
            Text("Apply the changes to all pages?")
                .appTextStyle(.itemTitle)
                .foregroundStyle(.text(.primary))
                .padding(.bottom, 24)
            
            HStack(spacing: 10) {
                AppButton(
                    config: AppButtonConfig(
                        content: .title("Yes"),
                        style: .primary,
                        size: .l,
                        isFullWidth: true
                    ),
                    action: {
                        withAnimation {
                            viewModel.notificationState = .none
                            viewModel.applyToAllQuads()
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
                        withAnimation {
                            viewModel.notificationState = .none
                        }
                    }
                )
            }
        }
        .padding(16)
        .background(.bg(.surface))
        .cornerRadius(24, corners: .allCorners)
        .frame(maxWidth: 300)
    }
}
