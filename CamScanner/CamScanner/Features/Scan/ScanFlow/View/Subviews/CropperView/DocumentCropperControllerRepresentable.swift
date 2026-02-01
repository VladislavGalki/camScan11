import SwiftUI

enum CropperAction: Equatable {
    case rotateLeft
    case rotateRight
    case setAll
    case setAuto
    case commit
}

struct DocumentCropperControllerRepresentable: UIViewControllerRepresentable {
    let cropperModel: DocumentCropperModel

    @Binding var action: CropperAction?
    
    let onCropped: (DocumentCropperModel) -> Void

    func makeUIViewController(context: Context) -> DocumentCropperViewController {
        let vc = DocumentCropperViewController(cropperModel: cropperModel)
        
        vc.onCropped = { cropperModel in
            onCropped(cropperModel)
        }
        
        context.coordinator.vc = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: DocumentCropperViewController, context: Context) {
        guard let action else { return }
        DispatchQueue.main.async {
            self.action = nil
        }

        switch action {
        case .rotateLeft: uiViewController.rotateLeft()
        case .rotateRight: uiViewController.rotateRight()
        case .setAll: uiViewController.setAllQuad()
        case .setAuto: uiViewController.setAutoQuad()
        case .commit: uiViewController.commitCrop()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var vc: DocumentCropperViewController?
    }
}
