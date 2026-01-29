import SwiftUI

struct PassportView: View {
    @ObservedObject var ui: ScanUIStateStore
    
    var body: some View {
        IdCardDriverLicenseFrameOverlayRepresentable(
            layout: .aspectFit(
                horizontalPadding: 8,
                verticalPadding: 73,
                aspect: 314.0/409.0
            ),
            title: "",
            guideImage: UIImage(named: "passport_image")
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
    }
}
