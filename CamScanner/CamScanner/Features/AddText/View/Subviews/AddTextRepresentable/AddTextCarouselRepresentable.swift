import SwiftUI

struct AddTextCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var textItems: [DocumentTextItem]
    var selectedTextID: UUID?
    var editingTextID: UUID?
    var editingTextDraft: String
    weak var delegate: AddTextPageDelegate?

    func makeUIViewController(context: Context) -> AddTextCarouselController {
        AddTextCarouselController(
            models: models,
            textItems: textItems,
            selectedTextID: selectedTextID,
            editingTextID: editingTextID,
            editingTextDraft: editingTextDraft,
            delegate: delegate
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
