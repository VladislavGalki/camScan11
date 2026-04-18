import SwiftUI

struct IdCardDriverLicenseView: View {
    @ObservedObject var ui: ScanUIStateStore
    var shouldShowGrid: Bool = false
    
    var body: some View {
        IdCardDriverLicenseFrameOverlayRepresentable(
            layout: .aspectFit(
                horizontalPadding: 44,
                verticalPadding: 90,
                aspect: 314.0 / 202.0
            ),
            title: titleText,
            guideImage: nil,
            shouldShowGrid: shouldShowGrid
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
    }
    
    private var titleText: String {
        ui.idCaptureSide == .front ? "Front side" : "Back side"
    }
}
