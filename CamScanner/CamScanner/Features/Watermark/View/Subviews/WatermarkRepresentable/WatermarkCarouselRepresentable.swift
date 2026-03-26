import SwiftUI

struct WatermarkCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var watermarkItems: [DocumentWatermarkItem]
    var selectedWatermarkID: UUID?
    var editingWatermarkID: UUID?
    var editingTextDraft: String
    var isScrollDisabled: Bool = false
    weak var delegate: WatermarkPageDelegate?

    func makeUIViewController(context: Context) -> WatermarkCarouselController {
        WatermarkCarouselController(
            models: models,
            watermarkItems: watermarkItems,
            selectedWatermarkID: selectedWatermarkID,
            editingWatermarkID: editingWatermarkID,
            editingTextDraft: editingTextDraft,
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
            isScrollDisabled: isScrollDisabled
        )
    }
}
