import Foundation
import Combine
import UIKit

@MainActor
final class OpenDocumentViewModel: ObservableObject {
    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var title: String = ""
    @Published var textItems: [DocumentTextItem] = []
    @Published var filterPreviewItems: [ScanFilterPreviewModel] = []
    @Published var sliderValue: Double = 0.5

    private var sliderRenderTask: Task<Void, Never>?
    private var scheduledFilterPreviewTask: Task<Void, Never>?
    private var filterPreviewGenerationTask: Task<Void, Never>?
    private var didScheduleInitialFilterPreviewGeneration = false

    private let filterPreviewCacheService = FilterPreviewCacheService()
    private let filterPreviewMaxDimension: CGFloat = 240

    private let inputModel: OpenDocumentInputModel
    private let store: OpenDocumentStore
    private let documentRepository = DocumentRepository.shared
    private let filterRenderer = FilterRenderer.shared

    private var currentCellHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init(inputModel: OpenDocumentInputModel) {
        self.inputModel = inputModel
        self.store = OpenDocumentStore(documentID: inputModel.documentID)

        subscribe()
        bootstrap()
    }

    deinit {
        sliderRenderTask?.cancel()
        scheduledFilterPreviewTask?.cancel()
        filterPreviewGenerationTask?.cancel()
    }

    private func bootstrap() {
        title = (try? documentRepository.fetchDocumentTitle(id: inputModel.documentID)) ?? ""
    }

    private func subscribe() {
        store.previewModelsPublisher
            .sink { [weak self] models in
                guard let self else { return }

                Task.detached(priority: .userInitiated) {
                    let preparedModels = models.map { model in
                        ScanPreviewModel(
                            documentType: model.documentType,
                            frames: OpenDocumentFramePreparer.preparedFrames(model.frames)
                        )
                    }

                    await MainActor.run {
                        self.models = preparedModels
                        self.selectedIndex = min(self.selectedIndex, max(preparedModels.count - 1, 0))
                        self.updateSliderFromCurrentFrame()
                        self.rebuildFilterPreviewItems()
                    }
                }
            }
            .store(in: &cancellables)

        store.textItemsPublisher
            .sink { [weak self] items in
                print("📝 OpenDocumentVM | textItems received: \(items.count)")
                for item in items {
                    print("📝 OpenDocumentVM |   [\(item.pageIndex)] \"\(item.text)\" center=(\(item.centerX), \(item.centerY)) size=(\(item.width), \(item.height)) fontSize=\(item.style.fontSize) rotation=\(item.rotation)")
                }
                self?.textItems = items
            }
            .store(in: &cancellables)
    }
}

// MARK: - Computed

extension OpenDocumentViewModel {
    var documentId: UUID {
        inputModel.documentID
    }
    
    var currentFilterType: DocumentFilterType {
        currentFrame?.currentFilter.type ?? .original
    }
    
    var currentFrame: CapturedFrame? {
        guard models.indices.contains(selectedIndex) else { return nil }
        return models[selectedIndex].frames.first
    }

    var shouldShowFilterStateButton: Bool {
        models.indices.contains(selectedIndex)
    }

    var shouldEnableUndoButton: Bool {
        guard let frame = currentFrame else { return false }
        return frame.filterHistory.currentIndex > 0
    }

    var shouldEnableRedoButton: Bool {
        guard let frame = currentFrame else { return false }
        return frame.filterHistory.currentIndex < frame.filterHistory.states.count - 1
    }
}

// MARK: - Public

extension OpenDocumentViewModel {
    func updateCellHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        currentCellHeight = height
    }

    func updateSelectedIndex(_ index: Int) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        rebuildFilterPreviewItems()
        updateSliderFromCurrentFrame()
    }

    func makeCropperInputModel() -> ScanCropperInputModel {
        ScanCropperInputModel(
            pageGroups: models.map {
                PreviewPageGroup(
                    documentType: $0.documentType,
                    frames: $0.frames
                )
            }
        )
    }

    func applyCropOutput(_ output: ScanPreviewInputModel) {
        models = output.pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: OpenDocumentFramePreparer.preparedFrames($0.frames)
            )
        }

        selectedIndex = min(selectedIndex, max(models.count - 1, 0))
        updateSliderFromCurrentFrame()
        rebuildFilterPreviewItems()
    }

    func reloadTextItems() {
        store.reloadTextItems()
    }

    func makeShareInputModel() -> ShareInputModel {
        var result = (try? documentRepository.loadShareModel(id: inputModel.documentID))
            ?? ShareInputModel(
                documentName: title,
                documentType: models.first?.documentType ?? .documents,
                pages: models
            )
        result.cellHeight = currentCellHeight
        print("📝 OpenDocumentVM | makeShareInputModel: docType=\(result.documentType) pages=\(result.pages.count) textItems=\(result.textItems.count) cellHeight=\(result.cellHeight)")
        for item in result.textItems {
            print("📝 OpenDocumentVM |   share textItem [\(item.pageIndex)] \"\(item.text)\" center=(\(item.centerX), \(item.centerY)) size=(\(item.width), \(item.height))")
        }
        return result
    }

    func rotatePage(at index: Int) {
        guard models.indices.contains(index) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.updatePage(at: index) { frame in
                var updated = frame
                var newState = updated.currentFilter
                newState.rotationAngle += .pi / 2
                updated.applyFilter(newState)
                
                if let base = updated.displayBase {
                    updated.preview = self?.filterRenderer.render(
                        image: base,
                        state: newState
                    )
                }
                
                return updated
            }
        }
        
        if index == selectedIndex {
            rebuildFilterPreviewItems()
            updateSliderFromCurrentFrame()
        }
    }
}

// MARK: - Filters

extension OpenDocumentViewModel {
    func previewSliderValue(_ slider: Double) {
        sliderValue = slider

        guard let frame = currentFrame,
              let base = frame.previewBase else { return }

        var tempState = frame.currentFilter
        tempState.adjustment = CGFloat(slider)

        sliderRenderTask?.cancel()

        let selectedIndex = self.selectedIndex

        sliderRenderTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let rendered = await self.filterRenderer.render(
                image: base,
                state: tempState
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.models.indices.contains(selectedIndex) else { return }

                var page = self.models[selectedIndex]
                page.frames = page.frames.map {
                    var copy = $0
                    copy.preview = rendered
                    return copy
                }

                self.models[selectedIndex] = page
            }
        }
    }

    func commitSliderValue(_ slider: Double) {
        sliderRenderTask?.cancel()

        guard models.indices.contains(selectedIndex) else { return }

        updatePage(at: selectedIndex) { frame in
            var updated = frame

            var newState = updated.currentFilter
            newState.adjustment = CGFloat(slider)

            updated.filterAdjustments[newState.type] = newState.adjustment
            updated.applyFilter(newState)

            guard let base = updated.previewBase else { return updated }

            updated.preview = filterRenderer.render(
                image: base,
                state: newState
            )

            return updated
        }
    }

    func applyFilter(_ type: DocumentFilterType) {
        guard let frame = currentFrame,
              let base = frame.previewBase else { return }

        sliderRenderTask?.cancel()

        guard let savedAdjustment = frame.filterAdjustments[type] ?? type.defaultSliderValue else { return  }
        sliderValue = Double(savedAdjustment)

        var state = frame.currentFilter
        state.type = type
        state.adjustment = savedAdjustment

        let newState = state
        let selectedIndex = self.selectedIndex

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let rendered = await self.filterRenderer.render(
                image: base,
                state: newState
            )

            await MainActor.run {
                guard self.models.indices.contains(selectedIndex) else { return }

                var page = self.models[selectedIndex]
                page.frames = page.frames.map {
                    var updated = $0
                    updated.applyFilter(newState)
                    updated.preview = rendered
                    updated.filterAdjustments[type] = newState.adjustment
                    return updated
                }

                self.models[selectedIndex] = page
                self.rebuildFilterPreviewItems()
            }
        }
    }

    func undoFilter() {
        guard models.indices.contains(selectedIndex) else { return }

        updatePage(at: selectedIndex) { frame in
            var updated = frame
            updated.undoFilter()

            guard let base = updated.previewBase else { return updated }

            updated.preview = filterRenderer.render(
                image: base,
                state: updated.currentFilter
            )

            return updated
        }

        updateSliderFromCurrentFrame()
        rebuildFilterPreviewItems()
    }

    func redoFilter() {
        guard models.indices.contains(selectedIndex) else { return }

        updatePage(at: selectedIndex) { frame in
            var updated = frame
            updated.redoFilter()

            guard let base = updated.previewBase else { return updated }

            updated.preview = filterRenderer.render(
                image: base,
                state: updated.currentFilter
            )

            return updated
        }

        updateSliderFromCurrentFrame()
        rebuildFilterPreviewItems()
    }

    func applyFilterToAllPages() {
        guard let referenceState = currentFrame?.currentFilter else { return }

        models = models.map { page in
            var updatedPage = page
            updatedPage.frames = page.frames.map { frame in
                var updated = frame
                updated.applyFilter(referenceState)

                guard let base = updated.displayBase else { return updated }

                updated.preview = filterRenderer.render(
                    image: base,
                    state: referenceState
                )

                return updated
            }
            return updatedPage
        }

        updateSliderFromCurrentFrame()
        rebuildFilterPreviewItems()
    }
}

// MARK: - Private

private extension OpenDocumentViewModel {
    func updateSliderFromCurrentFrame() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sliderValue = self.currentFrame.map { Double($0.currentFilter.adjustment) } ?? 0
        }
    }

    func updatePage(
        at index: Int,
        transform: (CapturedFrame) -> CapturedFrame
    ) {
        guard models.indices.contains(index) else { return }

        var page = models[index]
        page.frames = page.frames.map(transform)
        models[index] = page
    }

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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for index in self.filterPreviewItems.indices {
                    let filter = self.filterPreviewItems[index].filter
                    self.filterPreviewItems[index].isEnabled = true
                    self.filterPreviewItems[index].isSelected = frame.currentFilter.type == filter
                }
            }
        }

        scheduledFilterPreviewTask?.cancel()
        filterPreviewGenerationTask?.cancel()

        if !didScheduleInitialFilterPreviewGeneration {
            didScheduleInitialFilterPreviewGeneration = true

            scheduledFilterPreviewTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                guard let self, let frame = self.currentFrame else { return }
                self.startFilterPreviewGeneration(for: frame)
            }

            return
        }

        startFilterPreviewGeneration(for: frame)
    }

    func startFilterPreviewGeneration(for frame: CapturedFrame) {
        guard let base = frame.previewBase else { return }

        let previewBase = base.downscaled(maxDimension: filterPreviewMaxDimension)
        let cacheKey = "\(frame.id.uuidString)_filters_no_rotation_\(Int(filterPreviewMaxDimension))_\(previewBase.hashValue)"

        let selectedFilter = frame.currentFilter.type
        let prioritizedFilters =
            [selectedFilter, .original] +
            DocumentFilterType.allCases.filter {
                $0 != selectedFilter && $0 != .original
            }

        filterPreviewGenerationTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            for filter in prioritizedFilters {
                guard !Task.isCancelled else { return }

                var state = frame.currentFilter
                state.type = filter
                state.rotationAngle = 0

                let preview = await self.filterPreviewCacheService.preview(
                    cacheKey: cacheKey,
                    state: state,
                    base: previewBase
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
}

// MARK: - Helpers

enum OpenDocumentFramePreparer {
    static func preparedFrames(_ frames: [CapturedFrame]) -> [CapturedFrame] {
        let validFrames = frames.filter { $0.preview != nil }

        return validFrames.map { frame in
            var copy = frame

            if copy.previewBase == nil {
                let sourceBase =
                    copy.drawingBase ??
                    copy.original ??
                    copy.preview

                if let sourceBase {
                    copy.previewBase = ImageCompressionService.shared.compress(
                        sourceBase,
                        maxDimension: 1200,
                        quality: 0.90
                    )
                }
            }

            if copy.displayBase == nil {
                copy.displayBase = copy.previewBase
            }

            copy.preview = copy.displayBase
            return copy
        }
    }
}

actor FilterPreviewCacheService {
    private var cache: [String: [DocumentFilterType: UIImage]] = [:]
    private let filterRenderer = FilterRenderer.shared

    func preview(
        cacheKey: String,
        state: FilterState,
        base: UIImage
    ) -> UIImage {
        if let cached = cache[cacheKey]?[state.type] {
            return cached
        }

        let rendered = filterRenderer.render(
            image: base,
            state: state
        ) ?? base

        cache[cacheKey, default: [:]][state.type] = rendered
        return rendered
    }

    func clear() {
        cache.removeAll()
    }
}
