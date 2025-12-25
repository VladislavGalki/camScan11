import SwiftUI

struct ScanBottomBar: View {
    let isCapturing: Bool
    let onShutter: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            DocumentTypeCarouselView()

            ShutterButton(isBusy: isCapturing) {
                onShutter()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}
