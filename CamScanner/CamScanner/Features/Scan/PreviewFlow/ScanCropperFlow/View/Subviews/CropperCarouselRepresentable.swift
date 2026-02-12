import SwiftUI

struct CropperCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var onPageChanged: (Int) -> Void

    func makeUIViewController(context: Context) -> CropperCarouselController {
        CropperCarouselController(
            models: models,
            onPageChanged: onPageChanged
        )
    }

    func updateUIViewController(
        _ controller: CropperCarouselController,
        context: Context
    ) {
        controller.update(models)
    }
}
