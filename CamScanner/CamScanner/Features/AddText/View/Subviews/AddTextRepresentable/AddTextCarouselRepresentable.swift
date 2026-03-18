import SwiftUI

struct AddTextCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var textItems: [DocumentTextItem]
    var selectedTextID: UUID?

    var onPageChanged: (Int) -> Void
    var onPageTap: (Int, CGPoint, CGSize) -> Void
    var onTextTap: (UUID) -> Void
    var onSelectedTextFrameChanged: (UUID, CGRect?) -> Void
    var onTextMove: (UUID, CGPoint) -> Void
    var onTextResize: (UUID, CGFloat, CGFloat?) -> Void
    var onResizeStateChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> AddTextCarouselController {
        AddTextCarouselController(
            models: models,
            textItems: textItems,
            selectedTextID: selectedTextID,
            onPageChanged: onPageChanged,
            onPageTap: onPageTap,
            onTextTap: onTextTap,
            onSelectedTextFrameChanged: onSelectedTextFrameChanged,
            onTextMove: onTextMove,
            onTextResize: onTextResize,
            onResizeStateChanged: onResizeStateChanged
        )
    }

    func updateUIViewController(_ vc: AddTextCarouselController, context: Context) {
        vc.update(
            models: models,
            textItems: textItems,
            selectedTextID: selectedTextID
        )
    }
}
