import SwiftUI

struct OpenDocumentCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var textItems: [DocumentTextItem]

    @Binding var actionBottomBarAction: ScanPreviewBottomBarAction?

    var onPageChanged: (Int) -> Void
    var onRotatePage: (Int) -> Void

    func makeUIViewController(context: Context) -> OpenDocumentCarouselController {
        OpenDocumentCarouselController(
            models: models,
            textItems: textItems,
            onPageChanged: onPageChanged,
            onRotatePage: onRotatePage
        )
    }

    func updateUIViewController(_ vc: OpenDocumentCarouselController, context: Context) {
        vc.update(models, textItems: textItems)

        if let actionBottomBarAction {
            vc.handleBottomBarAction(actionBottomBarAction)

            DispatchQueue.main.async {
                self.actionBottomBarAction = nil
            }
        }
    }
}
