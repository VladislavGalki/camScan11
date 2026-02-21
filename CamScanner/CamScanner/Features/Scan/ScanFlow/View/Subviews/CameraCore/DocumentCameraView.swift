import SwiftUI

struct DocumentCameraView: UIViewRepresentable {
    @ObservedObject var camera: ScanCameraService
    let isLiveDetectionEnabled: Bool
    
    var onHintChanged: ((ScanHintState) -> Void)?

    func makeUIView(context: Context) -> DocumentCameraUIView {
        let view = DocumentCameraUIView()
        view.isLiveDetectionEnabled = isLiveDetectionEnabled
        view.onHintChanged = onHintChanged
        camera.attach(previewLayer: view.videoPreviewLayer, overlayView: view)
        return view
    }

    func updateUIView(_ uiView: DocumentCameraUIView, context: Context) {
        uiView.isLiveDetectionEnabled = isLiveDetectionEnabled
    }
}
