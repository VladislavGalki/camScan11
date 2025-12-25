import SwiftUI

struct DocumentCameraView: UIViewRepresentable {

    @ObservedObject var camera: ScanCameraService

    func makeUIView(context: Context) -> DocumentCameraUIView {
        let view = DocumentCameraUIView()
        camera.attach(previewLayer: view.videoPreviewLayer, overlayView: view)
        return view
    }

    func updateUIView(_ uiView: DocumentCameraUIView, context: Context) {}
}
