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
                .padding(.horizontal, 16)
                .padding(.bottom, 37)

            carouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 167)

            bottomBarView
        }
        .navigationBarBackButtonHidden()
        .background(Color.bg(.main))
    }
}

private extension OpenDocumentView {
    var navigationView: some View {
        HStack(spacing: 10) {
            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.back),
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
                .onTapGesture {
                    //viewModel.shareActiveSheet = .renameFileSheet
                }

            AppButton(
                config: AppButtonConfig(
                    content: .iconOnly(.dots),
                    style: .secondary,
                    size: .m
                ),
                action: {
                    // что то хз что
                }
            )

            AppButton(
                config: AppButtonConfig(
                    content: .title("Share"),
                    style: .primary,
                    size: .m
                ),
                action: {
                }
            )
        }
        .padding(.bottom, 10)
    }
    
    var carouselView: some View {
        OpenDocumentCarouselRepresentable(
            models: viewModel.models,
            actionBottomBarAction: $bottomBarAction,
            onPageChanged: { index in
                viewModel.updateSelectedIndex(index)
            },
            onRotatePage: { index in
                viewModel.rotatePage(at: index)
            }
        )
    }
    
    var bottomBarView: some View {
        HStack {
            bottomItem(title: "Add Page", icon: .page_plus)
            bottomItem(title: "Filters", icon: .plus)
            bottomItem(title: "Crop", icon: .crop)
                .onTapGesture {
                    router.push(
                        OpenDocumentRoute.scanCropper(
                            viewModel.makeCropperInputModel(),
                            onFinish: { outputModel in
                                viewModel.applyCropOutput(outputModel)
                            }
                        )
                    )
                }
            bottomItem(title: "Rotate", icon: .rotate)
                .onTapGesture {
                    bottomBarAction = .rotate
                }
            bottomItem(title: "Add text", icon: .plus)
            bottomItem(title: "Signature", icon: .signature)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.bg(.surface))
    }

    func bottomItem(title: String, icon: AppIcon) -> some View {
        VStack(spacing: 4) {
            Image(appIcon: icon)
                .renderingMode(.template)
                .foregroundStyle(.elements(.secondary))

            Text(title)
                .appTextStyle(.tabBar)
                .foregroundStyle(.text(.secondary))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
