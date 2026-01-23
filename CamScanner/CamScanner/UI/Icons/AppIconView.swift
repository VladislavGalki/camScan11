import SwiftUI

public struct AppIconView: View {
    let icon: AppIcon
    let configSize: AppButtonConfig.Size

    public var body: some View {
        Image(appIcon: icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: imageSize().width, height: imageSize().height)
    }
    
    private func imageSize() -> CGSize {
        switch configSize {
        case .l:
            return CGSize(width: 24, height: 24)
        case .m:
            return CGSize(width: 22, height: 22)
        case .s:
            return CGSize(width: 16, height: 16)
        }
    }
}
