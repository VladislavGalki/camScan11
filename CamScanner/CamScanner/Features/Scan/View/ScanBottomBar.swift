import SwiftUI

struct ScanBottomBar: View {

    @Binding var captureMode: CaptureMode
    let isCapturing: Bool
    let onShutter: () -> Void

    var body: some View {
        VStack(spacing: 14) {

            Picker("", selection: $captureMode) {
                ForEach(CaptureMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 64)

            DocumentTypeCarousel()

            ShutterButton(isBusy: isCapturing) {
                onShutter()
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Color.black)
    }
}
