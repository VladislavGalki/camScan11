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
                .padding(.bottom, 95)
            
            cropperCarouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 73)
            
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
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
                .ignoresSafeArea(edges: .top)
        )
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
    
    private var bottomContainerView: some View {
        HStack(spacing: 0) {
            tabItemView(icon: .autoCrop, title: "Auto Crop")
                .onTapGesture {
                    viewModel.setAutoQuad()
                }
            tabItemView(icon: .expand, title: "Expand")
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
}
