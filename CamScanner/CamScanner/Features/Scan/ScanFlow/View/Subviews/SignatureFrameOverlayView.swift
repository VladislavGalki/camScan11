import SwiftUI

struct SignatureFrameOverlayView: View {
    @ObservedObject var ui: ScanUIStateStore

    var body: some View {
        IdCardDriverLicenseFrameOverlayRepresentable(
            layout: .fixed(width: 200, height: 129),
            title: "",
            guideImage: nil,
            shouldShowGrid: false
        ) { rect in
            ui.idFrameRectInCameraSpace = rect
        }
        .allowsHitTesting(false)
    }
}
