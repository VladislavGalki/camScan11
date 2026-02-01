import SwiftUI
import UIKit

struct MiniPreviewDocumentView: View {
    @ObservedObject var store: ScanStore
    
    let image: UIImage?
    let count: Int
    let onPreviewClick: () -> Void
    
    @ViewBuilder
    var body: some View {
        if let image {
            HStack(spacing: 8) {
                shapeCameraTypeView(image: image)
                    .cornerRadius(2, corners: .allCorners)
                
                Image(appIcon: .arrowForward)
                    .renderingMode(.template)
                    .foregroundStyle(.elements(.onImmersive))
            }
            .overlay(alignment: .topLeading) {
                AppBadge(
                    config: AppBadgeConfig(style: .count(count))
                ) {}
                    .offset(x: -8, y: -8)
            }
            .onTapGesture {
                onPreviewClick()
            }
        }
    }
    
    @ViewBuilder
    private func shapeCameraTypeView(image: UIImage) -> some View {
        switch store.ui.selectedDocumentType {
        case .documents:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 60)
            
        case .idCard, .driverLicense:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 40)
        case .passport:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 45, height: 60)
        default:
            EmptyView()
        }
    }
}
