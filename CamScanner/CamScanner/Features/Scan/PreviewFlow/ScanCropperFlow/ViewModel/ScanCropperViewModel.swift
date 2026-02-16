import Foundation
import UIKit

final class ScanCropperViewModel: ObservableObject {

    // MARK: Published

    @Published var pages: [ScanPreviewModel] = []
    @Published var notificationState: ScanCropperNotificationState = .none
    @Published var cropSelectedType: CropSelectedType = .autoCrop
    @Published var shouldShowApplyToAllButton: Bool = false
    @Published var selectedIndex: Int = 0

    // MARK: Private

    private let cropRenderer: CropRenderer
    private let input: ScanCropperInputModel
    private var initialQuads: [UUID : Quadrilateral?] = [:]
    private var quadHistories: [Int: ScanCropperQuadHistory] = [:]
    
    private let onFinish: (ScanPreviewInputModel) -> Void

    // MARK: Init

    init(
        cropRenderer: CropRenderer = CropRenderer.shared,
        input: ScanCropperInputModel,
        onFinish: @escaping (ScanPreviewInputModel) -> Void
    ) {
        self.cropRenderer = cropRenderer
        self.input = input
        self.onFinish = onFinish
        
        bootstrap()
        captureInitialQuads()
        bootstrapQuadHistories()
    }
    
    private func bootstrap() {
        var result: [ScanPreviewModel] = []
        
        input.pages.forEach { entry in
            let type = entry.documentType
            let frames = entry.frames.filter { $0.preview != nil }

            frames.forEach { frame in
                result.append(
                    ScanPreviewModel(
                        documentType: type,
                        frames: [frame]
                    )
                )

            }
        }

        pages = result
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
        applyCrop()
        onFinish(buildOutputModel())
    }
    
    private func applyCrop() {
        var updatedPages = pages
            for pageIndex in updatedPages.indices {
                updatedPages[pageIndex].frames =
                updatedPages[pageIndex].frames.map { frame in
                    var f = frame

                    guard let quad = f.quad, let baseImage = f.original ?? f.preview else { return f }
                    guard let cropped = cropRenderer.crop(image: baseImage, quad: quad ) else { return f }

                    f.preview = cropped
                    f.displayBase = cropped
                    f.previewBase = cropped
                    f.drawingBase = nil
                    f.drawingData = nil

                    return f
                }
            }

            pages = updatedPages
    }
    
    private func buildOutputModel() -> ScanPreviewInputModel {
        var pagesDict: [DocumentTypeEnum: [CapturedFrame]] = [:]

        for page in pages {
            let type = page.documentType
            let frames = page.frames
            pagesDict[type, default: []].append(contentsOf: frames)
        }

        return ScanPreviewInputModel(
            documentType: input.documentType,
            pages: pagesDict
        )
    }
}
