import Foundation
import UIKit

final class ScanCropperViewModel: ObservableObject {

    // MARK: Published

    @Published var pages: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0

    // MARK: Private

    private let input: ScanCropperInputModel
    private let onFinish: ([ScanPreviewModel]) -> Void

    // MARK: Init

    init(
        input: ScanCropperInputModel,
        onFinish: @escaping ([ScanPreviewModel]) -> Void
    ) {
        self.input = input
        self.onFinish = onFinish
        self.pages = input.pages
    }

    // MARK: Current frame

    var currentFrame: CapturedFrame? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex].frames.first
    }

    // MARK: Page selection

    func selectPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        selectedIndex = index
    }

    // MARK: Apply crop result

    func applyCropResult(
        index: Int,
        cropperModel: DocumentCropperModel
    ) {
        guard pages.indices.contains(index) else { return }

        var page = pages[index]

        page.frames = page.frames.map { frame in
            var f = frame

            f.preview = cropperModel.image
            f.quad = cropperModel.autoQuad

            // сбрасываем drawing после кропа
            f.drawingBase = nil

            return f
        }

        pages[index] = page
    }

    // MARK: Expand / Auto

    func setAutoQuad(
        index: Int,
        autoQuad: Quadrilateral?
    ) {
        guard pages.indices.contains(index) else { return }

        var page = pages[index]

        page.frames = page.frames.map { frame in
            var f = frame
            f.quad = autoQuad
            return f
        }

        pages[index] = page
    }

    func setFullQuad(index: Int, imageSize: CGSize) {
        guard pages.indices.contains(index) else { return }

        let quad = Quadrilateral(
            topLeft: .zero,
            topRight: CGPoint(x: imageSize.width, y: 0),
            bottomRight: CGPoint(x: imageSize.width, y: imageSize.height),
            bottomLeft: CGPoint(x: 0, y: imageSize.height)
        )

        var page = pages[index]

        page.frames = page.frames.map { frame in
            var f = frame
            f.quad = quad
            return f
        }

        pages[index] = page
    }

    // MARK: Finish

    func finishFlow() {
        onFinish(pages)
    }
}
