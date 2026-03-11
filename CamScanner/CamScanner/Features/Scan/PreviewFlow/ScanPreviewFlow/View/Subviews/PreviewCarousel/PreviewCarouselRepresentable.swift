import SwiftUI

struct PreviewCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    
    @Binding var actionBottomBarAction: ScanPreviewBottomBarAction?
    
    var onPageChanged: (Int) -> Void
    var onRotatePage: (Int) -> Void
    var onAddTapped: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PreviewCarouselController {
        PreviewCarouselController(
            models: models,
            onPageChanged: onPageChanged,
            onRotatePage: onRotatePage,
            onAddTapped: onAddTapped
        )
    }

    func updateUIViewController(_ vc: PreviewCarouselController, context: Context) {
        vc.update(models)
        
        if let actionBottomBarAction {
            vc.handleBottomBarAction(actionBottomBarAction)
            
            DispatchQueue.main.async {
                self.actionBottomBarAction = nil
            }
        }
    }

    final class Coordinator {
        let parent: PreviewCarouselRepresentable

        init(_ parent: PreviewCarouselRepresentable) {
            self.parent = parent
        }
    }
}
