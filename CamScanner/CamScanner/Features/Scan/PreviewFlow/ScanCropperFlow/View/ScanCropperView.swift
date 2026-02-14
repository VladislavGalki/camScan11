import SwiftUI

struct ScanCropperView: View {
    @StateObject private var viewModel: ScanCropperViewModel
    
    @EnvironmentObject private var router: Router
    
    init(
        input: ScanCropperInputModel,
        onFinish: @escaping ([ScanPreviewModel]) -> Void
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
            
                
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.check),
                    style: .primary,
                    size: .m
                ),
                action: {
                    // save
                }
            )
        }
        .overlay {
            Text("Crop")
                .appTextStyle(.bodySecondary)
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
                    viewModel.applyToAllQuads()
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
}
