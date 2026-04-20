import Foundation
import UIKit

final class ScanCropperViewModel: ObservableObject {

    // MARK: Published

    @Published var pages: [CropperPageItem] = []
    @Published var notificationState: ScanCropperNotificationState = .none
    @Published var cropSelectedType: CropSelectedType = .autoCrop
    @Published var shouldShowApplyToAllButton: Bool = false
    @Published var selectedIndex: Int = 0

    // MARK: Private

    private let cropRenderer: CropRenderer
    private let input: ScanCropperInputModel
    private var initialQuads: [UUID: Quadrilateral?] = [:]
    private var quadHistories: [Int: ScanCropperQuadHistory] = [:]

    private let onFinish: (ScanPreviewInputModel) -> Void

    // MARK: Init

    init(
        input: ScanCropperInputModel,
        onFinish: @escaping (ScanPreviewInputModel) -> Void,
        dependencies: AppDependencies
    ) {
        self.cropRenderer = dependencies.cropRenderer
        self.input = input
        self.onFinish = onFinish

        bootstrap()
        captureInitialQuads()
        bootstrapQuadHistories()
    }
    
    private func bootstrap() {
        pages = input.pageGroups.flatMap { group in
            group.frames.map { frame in
                CropperPageItem(
                    id: frame.id,
                    documentType: group.documentType,
                    frame: frame
                )
            }
        }
    }
    
    private func captureInitialQuads() {
        pages.forEach { page in
            initialQuads[page.id] = page.frame.quad
        }
    }
    
    private func bootstrapQuadHistories() {
        for index in pages.indices {
            guard let quad = pages[index].frame.quad else { continue }
            quadHistories[index] = ScanCropperQuadHistory(initial: quad)
        }
    }

    // MARK: Current frame

    var currentFrame: CapturedFrame? {
        guard pages.indices.contains(selectedIndex) else { return nil }
        return pages[selectedIndex].frame
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
        guard pages.indices.contains(index),
              let quad = cropperModel.autoQuad
        else { return }

        if quadHistories[index] == nil {
            quadHistories[index] = ScanCropperQuadHistory(initial: quad)
        }

        quadHistories[index]?.push(
            ScanCropperQuadState(quad: quad)
        )

        var page = pages[index]
        page.frame.preview = cropperModel.image
        page.frame.quad = quad
        page.frame.drawingBase = nil

        pages[index] = page
    }

    // MARK: Expand / Auto

    func setAutoQuad() {
        guard pages.indices.contains(selectedIndex) else { return }
        cropSelectedType = .autoCrop
        shouldShowApplyToAllButton = true

        var page = pages[selectedIndex]

        guard let quad = initialQuads[page.id] ?? nil else { return }

        if quadHistories[selectedIndex] == nil {
            quadHistories[selectedIndex] = ScanCropperQuadHistory(initial: quad)
        }

        quadHistories[selectedIndex]?.push(
            ScanCropperQuadState(quad: quad)
        )

        page.frame.quad = quad
        pages[selectedIndex] = page
    }

    func setFullQuad() {
        guard pages.indices.contains(selectedIndex) else { return }
        cropSelectedType = .expand
        shouldShowApplyToAllButton = true

        var page = pages[selectedIndex]

        guard let image = page.frame.original ?? page.frame.preview else { return }

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

        page.frame.quad = quad
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
        page.frame.quad = quad
        pages[index] = page
    }
    
    func undoQuad() {
        shouldShowApplyToAllButton = false

        guard pages.indices.contains(selectedIndex),
              var history = quadHistories[selectedIndex]
        else { return }

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
        else { return }

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

                guard let image = page.frame.original ?? page.frame.preview else { continue }

                page.frame.quad = Quadrilateral(
                    topLeft: .zero,
                    topRight: CGPoint(x: image.size.width, y: 0),
                    bottomRight: CGPoint(x: image.size.width, y: image.size.height),
                    bottomLeft: CGPoint(x: 0, y: image.size.height)
                )

                pages[index] = page
            }

        case .autoCrop:
            for index in pages.indices {
                var page = pages[index]

                if let initialQuad = initialQuads[page.id] ?? nil {
                    page.frame.quad = initialQuad
                }

                pages[index] = page
            }
        }
    }
    
    private func applyQuad(_ quad: Quadrilateral, to index: Int) {
        var page = pages[index]
        page.frame.quad = quad
        pages[index] = page
    }

    // MARK: Finish

    func finishFlow() {
        applyCrop()
        onFinish(buildOutputModel())
    }
    
    private func applyCrop() {
        var updatedPages = pages

        for index in updatedPages.indices {
            var page = updatedPages[index]

            guard let quad = page.frame.quad,
                  let baseImage = page.frame.original ?? page.frame.preview,
                  let cropped = cropRenderer.crop(image: baseImage, quad: quad)
            else { continue }

            page.frame.preview = cropped
            page.frame.displayBase = cropped
            page.frame.previewBase = cropped
            page.frame.drawingBase = nil
            page.frame.drawingData = nil

            updatedPages[index] = page
        }

        pages = updatedPages
    }
    
    func buildOutputModel() -> ScanPreviewInputModel {
        ScanPreviewInputModel(
            pageGroups: makePageGroups(from: pages)
        )
    }
}

private extension ScanCropperViewModel {
    private func makePageGroups(from items: [CropperPageItem]) -> [PreviewPageGroup] {
        guard !items.isEmpty else { return [] }

        var result: [PreviewPageGroup] = []
        var index = 0

        while index < items.count {
            let current = items[index]

            switch current.documentType {
            case .documents, .passport:
                result.append(
                    PreviewPageGroup(
                        documentType: current.documentType,
                        frames: [current.frame]
                    )
                )
                index += 1

            case .idCard, .driverLicense:
                var frames: [CapturedFrame] = [current.frame]

                if index + 1 < items.count,
                   items[index + 1].documentType == current.documentType {
                    frames.append(items[index + 1].frame)
                    index += 2
                } else {
                    index += 1
                }

                result.append(
                    PreviewPageGroup(
                        documentType: current.documentType,
                        frames: frames
                    )
                )
            case .qrCode:
                index += 1
            }
        }

        return result
    }
}
