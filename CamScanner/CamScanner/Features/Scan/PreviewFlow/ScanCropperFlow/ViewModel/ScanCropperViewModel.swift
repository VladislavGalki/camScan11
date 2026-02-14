import Foundation
import UIKit

final class ScanCropperViewModel: ObservableObject {

    // MARK: Published

    @Published var pages: [ScanPreviewModel] = []
    @Published var cropSelectedType: CropSelectedType = .autoCrop
    @Published var shouldShowApplyToAllButton: Bool = false
    @Published var selectedIndex: Int = 0

    // MARK: Private

    private let input: ScanCropperInputModel
    private var initialQuads: [UUID : Quadrilateral?] = [:]
    private var quadHistories: [Int: ScanCropperQuadHistory] = [:]
    
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
        bootstrapQuadHistories()
    }
    
    private func captureInitialQuads() {
        pages.forEach { page in
            page.frames.forEach { frame in
                initialQuads[frame.id] = frame.quad
            }
        }
    }
    
    private func bootstrapQuadHistories() {
        for index in pages.indices {
            guard let quad = pages[index].frames.first?.quad else { continue }
            quadHistories[index] = ScanCropperQuadHistory(initial: quad)
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
    
    var canUndoQuad: Bool {
        guard let history = quadHistories[selectedIndex] else { return false }
        return history.canUndo
    }

    var canRedoQuad: Bool {
        guard let history = quadHistories[selectedIndex] else { return false }
        return history.canRedo
    }

    // MARK: Apply crop result

    func applyCropResult(
        index: Int,
        cropperModel: DocumentCropperModel
    ) {
        guard pages.indices.contains(index), let quad = cropperModel.autoQuad else { return }

        if quadHistories[index] == nil {
            quadHistories[index] = ScanCropperQuadHistory(initial: quad)
        }

        quadHistories[index]?.push(
            ScanCropperQuadState(quad: quad)
        )

        var page = pages[index]
        page.frames = page.frames.map { frame in
            var f = frame
            f.preview = cropperModel.image
            f.quad = quad
            f.drawingBase = nil
            return f
        }

        pages[index] = page
    }

    // MARK: Expand / Auto

    func setAutoQuad() {
        guard pages.indices.contains(selectedIndex) else { return }
        cropSelectedType = .autoCrop
        shouldShowApplyToAllButton = true
        var page = pages[selectedIndex]
        
        page.frames = page.frames.map { frame in
            var f = frame
            
            guard let quad = initialQuads[f.id], let quad else { return f }

            if quadHistories[selectedIndex] == nil {
                quadHistories[selectedIndex] = ScanCropperQuadHistory(initial: quad)
            }

            quadHistories[selectedIndex]?.push(
                ScanCropperQuadState(quad: quad)
            )

            f.quad = quad

            return f
        }

        pages[selectedIndex] = page
    }

    func setFullQuad() {
        guard pages.indices.contains(selectedIndex) else { return }
        cropSelectedType = .expand
        shouldShowApplyToAllButton = true
        
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

            if quadHistories[selectedIndex] == nil {
                quadHistories[selectedIndex] = ScanCropperQuadHistory(initial: quad)
            }

            quadHistories[selectedIndex]?.push(
                ScanCropperQuadState(quad: quad)
            )

            f.quad = quad

            return f
        }

        pages[selectedIndex] = page
    }
    
    func setChangedQuad(index: Int, quad: Quadrilateral) {
        guard pages.indices.contains(index) else { return }
        shouldShowApplyToAllButton = false

        if quadHistories[index] == nil {
            quadHistories[index] = ScanCropperQuadHistory(initial: quad)
        }

        if quadHistories[index]?.current.quad != quad {
            quadHistories[index]?.push(
                ScanCropperQuadState(quad: quad)
            )
        }

        var page = pages[index]

        page.frames = page.frames.map { frame in
            var f = frame
            f.quad = quad
            return f
        }

        pages[index] = page
    }
    
    func undoQuad() {
        shouldShowApplyToAllButton = false
        guard pages.indices.contains(selectedIndex),
              var history = quadHistories[selectedIndex]
        else {
            return
        }

        history.undo()

        quadHistories[selectedIndex] = history

        applyQuad(
            history.current.quad,
            to: selectedIndex
        )
    }
    
    func redoQuad() {
        shouldShowApplyToAllButton = false
        guard pages.indices.contains(selectedIndex),
              var history = quadHistories[selectedIndex]
        else {
            return
        }

        history.redo()

        quadHistories[selectedIndex] = history

        applyQuad(
            history.current.quad,
            to: selectedIndex
        )
    }
    
    func applyToAllQuads() {
        shouldShowApplyToAllButton = false
        
        switch cropSelectedType {
        case .expand:
            for index in pages.indices {
                var page = pages[index]

                page.frames = page.frames.map { frame in
                    var f = frame
                    
                    guard let image = f.original ?? f.preview else { return f }

                    f.quad = Quadrilateral(
                        topLeft: .zero,
                        topRight: CGPoint(x: image.size.width, y: 0),
                        bottomRight: CGPoint(x: image.size.width, y: image.size.height),
                        bottomLeft: CGPoint(x: 0, y: image.size.height)
                    )
                    return f
                }
                pages[index] = page
            }
        case .autoCrop:
            for index in pages.indices {
                var page = pages[index]
                page.frames = page.frames.map { frame in
                    var f = frame

                    if let initialQuad = initialQuads[f.id] {
                        f.quad = initialQuad
                    }

                    return f
                }

                pages[index] = page
            }
        }
    }
    
    private func applyQuad(_ quad: Quadrilateral, to index: Int) {
        var page = pages[index]

        page.frames = page.frames.map {
            var f = $0
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
