import SwiftUI

struct WatermarkCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var watermarkItems: [DocumentWatermarkItem]
    var selectedWatermarkID: UUID?
    var editingWatermarkID: UUID?
    var editingTextDraft: String
    var isScrollDisabled: Bool = false
    var isInteractionDisabled: Bool = false
    weak var delegate: WatermarkPageDelegate?

    func makeUIViewController(context: Context) -> WatermarkCarouselController {
        WatermarkCarouselController(
            models: models,
            watermarkItems: watermarkItems,
            selectedWatermarkID: selectedWatermarkID,
            editingWatermarkID: editingWatermarkID,
            editingTextDraft: editingTextDraft,
            isInteractionDisabled: isInteractionDisabled,
            delegate: delegate
        )
    }

    func updateUIViewController(_ vc: WatermarkCarouselController, context: Context) {
        vc.update(
            models: models,
            watermarkItems: watermarkItems,
            selectedWatermarkID: selectedWatermarkID,
            editingWatermarkID: editingWatermarkID,
            editingTextDraft: editingTextDraft,
            isInteractionDisabled: isInteractionDisabled,
            isScrollDisabled: isScrollDisabled
        )
    }
}
