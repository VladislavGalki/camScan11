import SwiftUI

struct OpenDocumentCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var textItems: [DocumentTextItem]
    var watermarkItems: [DocumentWatermarkItem]
    var signatureItems: [DocumentSignatureItem]

    @Binding var actionBottomBarAction: ScanPreviewBottomBarAction?

    var onPageChanged: (Int) -> Void
    var onRotatePage: (Int) -> Void
    var onCellHeightChanged: (CGFloat) -> Void = { _ in }

    func makeUIViewController(context: Context) -> OpenDocumentCarouselController {
        OpenDocumentCarouselController(
            models: models,
            textItems: textItems,
            watermarkItems: watermarkItems,
            signatureItems: signatureItems,
            onPageChanged: onPageChanged,
            onRotatePage: onRotatePage,
            onCellHeightChanged: onCellHeightChanged
        )
    }

    func updateUIViewController(_ vc: OpenDocumentCarouselController, context: Context) {
        vc.update(models, textItems: textItems, watermarkItems: watermarkItems, signatureItems: signatureItems)

        if let actionBottomBarAction {
            vc.handleBottomBarAction(actionBottomBarAction)

            DispatchQueue.main.async {
                self.actionBottomBarAction = nil
            }
        }
    }
}
