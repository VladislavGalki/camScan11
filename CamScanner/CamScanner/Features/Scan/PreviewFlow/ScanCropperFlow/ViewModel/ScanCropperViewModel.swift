import Foundation
import UIKit

final class ScanCropperViewModel: ObservableObject {

    // MARK: Published

    @Published var pages: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0

    // MARK: Private

    private let input: ScanCropperInputModel
    private var initialQuads: [UUID : Quadrilateral?] = [:]
    
    private let onFinish: ([ScanPreviewModel]) -> Void

    // MARK: Init

    init(
        input: ScanCropperInputModel,
        onFinish: @escaping ([ScanPreviewModel]) -> Void
    ) {
        self.input = input
        self.onFinish = onFinish
        self.pages = input.pages
        
        captureInitialQuads()
    }
    
    private func captureInitialQuads() {
        pages.forEach { page in
            page.frames.forEach { frame in
                initialQuads[frame.id] = frame.quad
            }
        }
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
            f.drawingBase = nil

            return f
        }

        pages[index] = page
    }

    // MARK: Expand / Auto

    func setAutoQuad() {
        guard pages.indices.contains(selectedIndex) else { return }

        var page = pages[selectedIndex]

        page.frames = page.frames.map { frame in
            var f = frame
            f.quad = initialQuads[f.id] ?? f.quad
            return f
        }

        pages[selectedIndex] = page
    }

    func setFullQuad() {
        guard pages.indices.contains(selectedIndex) else { return }

        var page = pages[selectedIndex]

        page.frames = page.frames.map { frame in
            var f = frame

            guard let image = f.original ?? f.preview else { return f }

            let quad = Quadrilateral(
                topLeft: .zero,
                topRight: CGPoint(x: image.size.width, y: 0),
                bottomRight: CGPoint(x: image.size.width, y: image.size.height),
                bottomLeft: CGPoint(x: 0, y: image.size.height)
            )

            f.quad = quad
            return f
        }

        pages[selectedIndex] = page
    }
    
    func setChangedQuad(index: Int, quad: Quadrilateral) {
        guard pages.indices.contains(index) else { return }
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
