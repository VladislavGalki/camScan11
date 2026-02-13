import SwiftUI

struct CropperCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var onPageChanged: (Int) -> Void
    var onQuadChanged: (Int, Quadrilateral) -> Void
    
    func makeUIViewController(context: Context) -> CropperCarouselController {
        CropperCarouselController(
            models: models,
            onPageChanged: onPageChanged,
            onQuadChanged: onQuadChanged
        )
    }

    func updateUIViewController(
        _ controller: CropperCarouselController,
        context: Context
    ) {
        controller.update(models)
    }
}
