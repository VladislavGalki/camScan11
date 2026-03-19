import SwiftUI

struct AddTextCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var textItems: [DocumentTextItem]
    var selectedTextID: UUID?
    var editingTextID: UUID?
    var editingTextDraft: String

    var onPageChanged: (Int) -> Void
    var onPageTap: (Int, CGPoint, CGSize) -> Void
    var onTextTap: (UUID) -> Void
    var onSelectedTextFrameChanged: (UUID, CGRect?) -> Void
    var onTextMove: (UUID, CGPoint) -> Void
    var onTextResize: (UUID, CGFloat, CGFloat?, CGSize) -> Void
    var onPageSizeChanged: (CGSize) -> Void
    var onResizeStateChanged: (Bool) -> Void
    var onEditingTextChanged: (String, CGSize) -> Void
    var onEditingSubmit: () -> Void
    var onScrollStarted: () -> Void

    func makeUIViewController(context: Context) -> AddTextCarouselController {
        AddTextCarouselController(
            models: models,
            textItems: textItems,
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft,
            onPageChanged: onPageChanged,
            onPageTap: onPageTap,
            onTextTap: onTextTap,
            onSelectedTextFrameChanged: onSelectedTextFrameChanged,
            onTextMove: onTextMove,
            onTextResize: onTextResize,
            onPageSizeChanged: onPageSizeChanged,
            onResizeStateChanged: onResizeStateChanged,
            onEditingTextChanged: onEditingTextChanged,
            onEditingSubmit: onEditingSubmit,
            onScrollStarted: onScrollStarted
        )
    }

    func updateUIViewController(_ vc: AddTextCarouselController, context: Context) {
        vc.update(
            models: models,
            textItems: textItems,
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft
        )
    }
}
