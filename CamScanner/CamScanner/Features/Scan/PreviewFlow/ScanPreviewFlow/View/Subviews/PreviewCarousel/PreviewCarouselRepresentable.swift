import SwiftUI

struct PreviewCarouselRepresentable: UIViewControllerRepresentable {
    var images: [UIImage]
    var onPageChanged: (Int) -> Void
    var onAddTapped: () -> Void

    func makeUIViewController(context: Context) -> PreviewCarouselController {
        PreviewCarouselController(
            images: images,
            onPageChanged: onPageChanged,
            onAddTapped: onAddTapped
        )
    }

    func updateUIViewController(_ vc: PreviewCarouselController, context: Context) {
        vc.update(images)
    }
}
