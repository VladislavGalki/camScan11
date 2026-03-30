import SwiftUI

struct EraseCarouselRepresentable: UIViewControllerRepresentable {
    var models: [ScanPreviewModel]
    var strokesByPage: [Int: [Stroke]]
    var selectedIndex: Int
    var isAutoColor: Bool
    var eraseColor: UIColor
    var brushSize: CGFloat
    var isScrollDisabled: Bool = false
    weak var delegate: ErasePageDelegate?

    func makeUIViewController(context: Context) -> EraseCarouselController {
        EraseCarouselController(
            models: models,
            strokesByPage: strokesByPage,
            selectedIndex: selectedIndex,
            isAutoColor: isAutoColor,
            eraseColor: eraseColor,
            brushSize: brushSize,
            delegate: delegate
        )
    }

    func updateUIViewController(_ vc: EraseCarouselController, context: Context) {
        vc.update(
            models: models,
            strokesByPage: strokesByPage,
            selectedIndex: selectedIndex,
            isAutoColor: isAutoColor,
            eraseColor: eraseColor,
            brushSize: brushSize,
            isScrollDisabled: isScrollDisabled
        )
    }
}
