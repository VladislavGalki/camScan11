import SwiftUI

struct CropperCarouselRepresentable: UIViewControllerRepresentable {
    var models: [CropperPageItem]
    var onPageChanged: (Int) -> Void
    var onQuadChanged: (Int, Quadrilateral) -> Void

    init(
        models: [CropperPageItem],
        onPageChanged: @escaping (Int) -> Void,
        onQuadChanged: @escaping (Int, Quadrilateral) -> Void
    ) {
        self.models = models
        self.onPageChanged = onPageChanged
        self.onQuadChanged = onQuadChanged
    }

    func makeUIViewController(context: Context) -> CropperCarouselController {
        CropperCarouselController(
            models: models,
            onPageChanged: onPageChanged,
            onQuadChanged: onQuadChanged
        )
    }

    func updateUIViewController(_ controller: CropperCarouselController, context: Context) {
        controller.update(models)
    }
}
