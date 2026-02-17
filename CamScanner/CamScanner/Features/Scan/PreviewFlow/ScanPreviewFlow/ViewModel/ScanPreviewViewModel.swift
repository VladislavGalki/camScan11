import Foundation
import UIKit

final class ScanPreviewViewModel: ObservableObject {
    @Published var notificationState: ScanPreviewNotificationState = .none
    @Published var scanPreviewModel: [ScanPreviewModel] = []
    @Published var filterPreviewItems: [ScanFilterPreviewModel] = []

    private var filterPreviewCache: [String : [DocumentFilterType : UIImage]] = [:]
    private var selectedPageIndex: Int = 0

    private let filterRenderer: FilterRenderer
    private var inputModel: ScanPreviewInputModel
    
    private let onFinish: (ScanPreviewInputModel) -> Void

    init(inputModel: ScanPreviewInputModel, onFinish: @escaping (ScanPreviewInputModel) -> Void) {
        self.inputModel = inputModel
        self.filterRenderer = FilterRenderer.shared
        self.onFinish = onFinish
        bootstrap()
    }

    // MARK: - Public
    
    var documentType: DocumentTypeEnum {
        inputModel.documentType
    }

    var currentFrame: CapturedFrame? {
        guard selectedPageIndex < scanPreviewModel.count else { return nil }
        return scanPreviewModel[selectedPageIndex].frames.first
    }
    
    var shouldShowFilterStateButton: Bool {
        scanPreviewModel.indices.contains(selectedPageIndex)
    }
    
    var shouldDisableUndoButton: Bool {
        guard let frame = currentFrame else { return false }
        return frame.filterHistory.currentIndex > 0
    }

    var shouldDisableRedoButton: Bool {
        guard let frame = currentFrame else { return false }
        return frame.filterHistory.currentIndex < frame.filterHistory.states.count - 1
    }

    func updateSelectedPageIndex(_ index: Int) {
        selectedPageIndex = index
        rebuildFilterPreviewItems()
    }
    
    func applyCropOutput(_ output: ScanPreviewInputModel) {
        inputModel = output
        bootstrap()
    }
    
    func buildOutputModel() -> ScanPreviewInputModel {
        var pages: [DocumentTypeEnum: [CapturedFrame]] = [:]
        for page in scanPreviewModel {
            let type = page.documentType
            let frames = page.frames
            pages[type, default: []].append(contentsOf: frames)
        }

        return ScanPreviewInputModel(
            documentType: inputModel.documentType,
            pages: pages
        )
    }
    
    func buildOutputClearModel() -> ScanPreviewInputModel {
        ScanPreviewInputModel(documentType: documentType, pages: [:])
    }
    
    func onFinishFlow(_ outputModel: ScanPreviewInputModel) {
        onFinish(outputModel)
    }

    // MARK: - Delete

    func deletePage() -> Int? {
        guard scanPreviewModel.indices.contains(selectedPageIndex) else { return nil }

        let removedIndex = selectedPageIndex
        let removedFrames = scanPreviewModel[removedIndex].frames
        scanPreviewModel.remove(at: removedIndex)

        removedFrames.forEach { frame in
            filterPreviewCache = filterPreviewCache.filter {
                !$0.key.contains(frame.id.uuidString)
            }
        }

        if selectedPageIndex >= scanPreviewModel.count {
            selectedPageIndex = max(0, scanPreviewModel.count - 1)
        }

        rebuildFilterPreviewItems()
        return removedIndex
    }

    // MARK: - Rotation (через state!)

    func rotatePage(at index: Int) {
        guard scanPreviewModel.indices.contains(index) else { return }

        var page = scanPreviewModel[index]

        page.frames = page.frames.map { frame in
            var f = frame

            var newState = f.currentFilter
            newState.rotationAngle += .pi / 2
            f.applyFilter(newState)

            guard let base = f.displayBase else { return f }

            f.preview = filterRenderer.render(
                image: base,
                state: newState
            )

            return f
        }

        DispatchQueue.main.async { [weak self] in
            self?.scanPreviewModel[index] = page
            self?.rebuildFilterPreviewItems()
        }
    }

    // MARK: - Filters UI

    func rebuildFilterPreviewItems() {
        let filters = DocumentFilterType.allCases

        guard let frame = currentFrame else {
            filterPreviewItems = filters.map {
                ScanFilterPreviewModel(
                    id: $0,
                    filter: $0,
                    previewImage: nil,
                    isSelected: false,
                    isEnabled: false
                )
            }
            return
        }

        if filterPreviewItems.isEmpty {
            filterPreviewItems = filters.map {
                ScanFilterPreviewModel(
                    id: $0,
                    filter: $0,
                    previewImage: nil,
                    isSelected: frame.currentFilter.type == $0,
                    isEnabled: true
                )
            }
        } else {
            for i in filterPreviewItems.indices {
                let filter = filterPreviewItems[i].filter
                filterPreviewItems[i].isEnabled = true
                filterPreviewItems[i].isSelected = frame.currentFilter.type == filter
            }
        }

        generateFilterPreviewsAsync(frame)
    }

    private func generateFilterPreviewsAsync(_ frame: CapturedFrame) {
        guard let base = frame.previewBase else { return }

        let cacheKey = "\(frame.id.uuidString)_\(base.hashValue)"
        let filters = DocumentFilterType.allCases

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            for filter in filters {

                var state = frame.currentFilter
                state.type = filter

                let preview = self.cachedPreview(
                    cacheKey: cacheKey,
                    state: state,
                    base: base
                )

                await MainActor.run {
                    guard let current = self.currentFrame else { return }
                    guard current.id == frame.id else { return }

                    guard let index = self.filterPreviewItems.firstIndex(where: {
                        $0.filter == filter
                    }) else { return }

                    self.filterPreviewItems[index].previewImage = preview
                }
            }
        }
    }

    private func cachedPreview(
        cacheKey: String,
        state: FilterState,
        base: UIImage
    ) -> UIImage {

        if let cached = filterPreviewCache[cacheKey]?[state.type] {
            return cached
        }

        let rendered = filterRenderer.render(
            image: base,
            state: state
        ) ?? base

        filterPreviewCache[cacheKey, default: [:]][state.type] = rendered
        return rendered
    }

    // MARK: - Apply Filter

    func applyFilter(_ type: DocumentFilterType) {
        guard scanPreviewModel.indices.contains(selectedPageIndex) else { return }

        var page = scanPreviewModel[selectedPageIndex]

        page.frames = page.frames.map { frame in
            var f = frame

            var newState = f.currentFilter
            newState.type = type
            f.applyFilter(newState)

            guard let base = f.displayBase else { return f }

            f.preview = filterRenderer.render(
                image: base,
                state: newState
            )

            return f
        }

        scanPreviewModel[selectedPageIndex] = page
        rebuildFilterPreviewItems()
    }

    // MARK: - Undo / Redo

    func undoFilter() {
        guard scanPreviewModel.indices.contains(selectedPageIndex) else { return }

        var page = scanPreviewModel[selectedPageIndex]

        page.frames = page.frames.map { frame in
            var f = frame
            f.undoFilter()

            guard let base = f.displayBase else { return f }

            f.preview = filterRenderer.render(
                image: base,
                state: f.currentFilter
            )

            return f
        }

        scanPreviewModel[selectedPageIndex] = page
        rebuildFilterPreviewItems()
    }

    func redoFilter() {
        guard scanPreviewModel.indices.contains(selectedPageIndex) else { return }

        var page = scanPreviewModel[selectedPageIndex]

        page.frames = page.frames.map { frame in
            var f = frame
            f.redoFilter()

            guard let base = f.displayBase else { return f }

            f.preview = filterRenderer.render(
                image: base,
                state: f.currentFilter
            )

            return f
        }

        scanPreviewModel[selectedPageIndex] = page
        rebuildFilterPreviewItems()
    }

    // MARK: - Apply To All Pages

    func applyFilterToAllPages() {
        guard let referenceState = currentFrame?.currentFilter else { return }
        scanPreviewModel = scanPreviewModel.map { page in
            var newPage = page
            newPage.frames = page.frames.map { frame in
                var f = frame
                f.applyFilter(referenceState)

                guard let base = f.displayBase else { return f }
                f.preview = filterRenderer.render(
                    image: base,
                    state: referenceState
                )

                return f
            }

            return newPage
        }

        rebuildFilterPreviewItems()
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        var result: [ScanPreviewModel] = []

        inputModel.pages.forEach { entry in
            let type = entry.key
            let frames = entry.value.filter { $0.preview != nil }
            
            let updatedFrames = frames.map { frame -> CapturedFrame in
                var copy = frame
                if copy.previewBase == nil {
                    copy.previewBase =
                        copy.drawingBase ??
                        copy.original ??
                        copy.preview
                }

                if copy.displayBase == nil {
                    copy.displayBase = copy.previewBase
                }

                if let base = copy.displayBase {
                    copy.preview = filterRenderer.render(
                        image: base,
                        state: copy.currentFilter
                    )
                }

                return copy
            }

            if type == .documents {
                updatedFrames.forEach { frame in
                    result.append(
                        ScanPreviewModel(
                            documentType: type,
                            frames: [frame]
                        )
                    )
                }
            } else {
                result.append(
                    ScanPreviewModel(
                        documentType: type,
                        frames: updatedFrames
                    )
                )
            }
        }

        scanPreviewModel = result
        updateSelectedPageIndex(selectedPageIndex)
    }
}
