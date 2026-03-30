import SwiftUI

struct EraseCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var strokes: [Stroke]
    var eraseColor: UIColor
    var brushSize: CGFloat
    var isScrollDisabled: Bool = false
    weak var delegate: ErasePageDelegate?

    func makeUIViewController(context: Context) -> EraseCarouselController {
        EraseCarouselController(
            models: models,
            strokes: strokes,
            eraseColor: eraseColor,
            brushSize: brushSize,
            delegate: delegate
        )
    }

    func updateUIViewController(_ vc: EraseCarouselController, context: Context) {
        vc.update(
            models: models,
            strokes: strokes,
            eraseColor: eraseColor,
            brushSize: brushSize,
            isScrollDisabled: isScrollDisabled
        )
    }
}
