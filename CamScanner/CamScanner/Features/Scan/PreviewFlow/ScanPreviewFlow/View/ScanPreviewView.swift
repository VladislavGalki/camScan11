import SwiftUI
import UIKit

struct ScanPreviewView: View {
    @EnvironmentObject private var router: Router
    
    var body: some View {
        VStack(spacing: 0) {
            navigationView
                .padding(.bottom, 37)
            
            documentCarouselView
                .frame(maxHeight: .infinity)
                .padding(.bottom, 37)
            
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
            images: [
                UIImage(systemName: "doc")!,
                UIImage(systemName: "doc.text")!,
                UIImage(systemName: "doc.richtext")!,
                UIImage(systemName: "doc.plaintext")!,
                UIImage(systemName: "doc.text.image")!,
                UIImage(systemName: "doc.badge.plus")!
            ],
            onPageChanged: { _ in },
            onAddTapped: {
                router.pop()
            }
        )
    }
    
    private var bottomContainerView: some View {
        HStack(spacing: 0) {
            tabItemView(icon: .page_plus, title: "Add page")
                .onTapGesture {
                    router.pop()
                }
            
            tabItemView(icon: .crop, title: "Crop")
            tabItemView(icon: .rotate, title: "Rotate")
            tabItemView(icon: .signature, title: "Signature")
            tabItemView(icon: .trash, title: "Delete")
        }
        .padding(.top, 12)
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .foregroundStyle(.bg(.surface))
                .appBorderModifier(.border(.primary), width: 1, radius: 0, corners: .allCorners)
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
