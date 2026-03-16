import SwiftUI

struct OpenDocumentCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]

    @Binding var actionBottomBarAction: ScanPreviewBottomBarAction?

    var onPageChanged: (Int) -> Void
    var onRotatePage: (Int) -> Void

    func makeUIViewController(context: Context) -> OpenDocumentCarouselController {
        OpenDocumentCarouselController(
            models: models,
            onPageChanged: onPageChanged,
            onRotatePage: onRotatePage
        )
    }

    func updateUIViewController(_ vc: OpenDocumentCarouselController, context: Context) {
        vc.update(models)

        if let actionBottomBarAction {
            vc.handleBottomBarAction(actionBottomBarAction)

            DispatchQueue.main.async {
                self.actionBottomBarAction = nil
            }
        }
    }
}
