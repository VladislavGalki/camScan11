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

        // 1. Compute rotated text positions (sync, uses current preview sizes)
        let updatedTextItems = computeRotatedTextItems(forPageIndex: index)
        let pageIndices = pageIndicesForModel(at: index)

        // Defer ALL @Published mutations to escape the current SwiftUI view update
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // 2. Apply text changes in-memory
            if let items = updatedTextItems {
                self.textItems = items
            }

            // 3. Update in-memory model (re-render preview)
            self.updatePage(at: index) { frame in
                var updated = frame
                var newState = updated.currentFilter
                newState.rotationAngle = (newState.rotationAngle + .pi / 2)
                    .truncatingRemainder(dividingBy: 2 * .pi)
                updated.applyFilter(newState)

                if let base = updated.displayBase {
                    updated.preview = self.filterRenderer.render(
                        image: base,
                        state: newState
                    )
                }

                return updated
            }

            if index == self.selectedIndex {
                self.rebuildFilterPreviewItems()
                self.updateSliderFromCurrentFrame()
            }

            // 4. Collect rotated preview images for saving to disk
            var pageImages: [(pageIndex: Int, image: UIImage)] = []
            if let model = self.models[safe: index] {
                for (frameIdx, dbPageIndex) in pageIndices.enumerated() {
                    if let preview = model.frames[safe: frameIdx]?.preview {
                        pageImages.append((pageIndex: dbPageIndex, image: preview))
                    }
                }
            }

            // 5. Save text coords + page rotation + images atomically
            let pageItems = (updatedTextItems ?? self.textItems)
                .filter { $0.pageIndex == index }
            try? self.documentRepository.saveRotationState(
                documentID: self.inputModel.documentID,
                textItems: pageItems,
                pageIndices: pageIndices,
                rotationAngleDelta: .pi / 2,
                pageImages: pageImages
            )
        }
    }

    private static let cardWidth: CGFloat = 322

    /// Returns updated text items with rotated coordinates, or nil if nothing changed.
    private func computeRotatedTextItems(forPageIndex pageIndex: Int) -> [DocumentTextItem]? {
        guard let model = models[safe: pageIndex] else { return nil }

        let cellW = Self.cardWidth
        let cellH = currentCellHeight
        guard cellW > 0, cellH > 0 else { return nil }

        let cellSize = CGSize(width: cellW, height: cellH)

        print("📐 ── ROTATE BEGIN ──────────────────────────────")
        print("📐 cell=\(cellW)×\(cellH) docType=\(model.documentType) framesCount=\(model.frames.count)")
        for (fi, frame) in model.frames.enumerated() {
            let pSize = frame.preview?.size ?? .zero
            let dSize = frame.displayBase?.size ?? .zero
            let angle = frame.currentFilter.rotationAngle
            print("📐 frame[\(fi)] preview=\(pSize.width)×\(pSize.height) displayBase=\(dSize.width)×\(dSize.height) rotAngle=\(angle)rad (\(angle * 180 / .pi)°)")
        }
        print("📐 textItems count=\(textItems.count) (pageIndex=\(pageIndex) items=\(textItems.filter { $0.pageIndex == pageIndex }.count))")

        var updatedItems = textItems
        var changed = false

        for i in updatedItems.indices where updatedItems[i].pageIndex == pageIndex {
            let item = updatedItems[i]
            let pos = CGPoint(x: item.centerX * cellW, y: item.centerY * cellH)

            guard let (beforeRect, afterRect) = contentRectsForRotation(
                model: model, position: pos, cellSize: cellSize
            ) else {
                print("📐 [\(i)] contentRectsForRotation returned nil – skipping")
                continue
            }

            // Cell pixel → content-normalized [0,1], clamped to image bounds.
            // Text placed slightly outside the image area (e.g. near edges when
            // image doesn't fill the cell) must be clamped to avoid mapping
            // outside cell bounds after rotation.
            let nx = min(1, max(0, (pos.x - beforeRect.minX) / beforeRect.width))
            let ny = min(1, max(0, (pos.y - beforeRect.minY) / beforeRect.height))

            // 90° CW in normalized content space
            let rx = 1 - ny
            let ry = nx

            // Content-normalized → cell-normalized
            let newCX = (afterRect.minX + rx * afterRect.width) / cellW
            let newCY = (afterRect.minY + ry * afterRect.height) / cellH

            print("📐 [\(i)] \"\(item.text)\" BEFORE center=(\(item.centerX), \(item.centerY)) size=(\(item.width), \(item.height)) rot=\(item.rotation)")
            print("📐 [\(i)] pixelPos=(\(pos.x), \(pos.y))")
            print("📐 [\(i)] beforeRect=(x:\(beforeRect.minX) y:\(beforeRect.minY) w:\(beforeRect.width) h:\(beforeRect.height))")
            print("📐 [\(i)] afterRect =(x:\(afterRect.minX) y:\(afterRect.minY) w:\(afterRect.width) h:\(afterRect.height))")
            print("📐 [\(i)] contentNorm=(\(nx), \(ny)) → rotated90CW=(\(rx), \(ry))")
            print("📐 [\(i)] AFTER  center=(\(newCX), \(newCY)) rot=\((item.rotation + 90).truncatingRemainder(dividingBy: 360))")

            updatedItems[i].centerX = newCX
            updatedItems[i].centerY = newCY
            updatedItems[i].rotation = (item.rotation + 90).truncatingRemainder(dividingBy: 360)

            changed = true
        }

        print("📐 ── ROTATE END ────────────────────────────────")
        return changed ? updatedItems : nil
    }

    /// Maps a model index to the corresponding PageEntity indices in the DB.
    private func pageIndicesForModel(at modelIndex: Int) -> [Int] {
        var startIndex = 0
        for i in 0..<modelIndex {
            startIndex += models[i].frames.count
        }
        let count = models[safe: modelIndex]?.frames.count ?? 0
        return Array(startIndex..<(startIndex + count))
    }

    // MARK: - Content rect helpers

    private func contentRectsForRotation(
        model: ScanPreviewModel,
        position: CGPoint,
        cellSize: CGSize
    ) -> (before: CGRect, after: CGRect)? {
        switch model.documentType {
        case .documents:
            return documentsContentRects(model: model, cellSize: cellSize)

        case .idCard, .driverLicense:
            return idCardContentRects(model: model, position: position, cellSize: cellSize)

        case .passport:
            return passportContentRects(model: model, cellSize: cellSize)

        case .qrCode:
            return nil
        }
    }

    private func documentsContentRects(
        model: ScanPreviewModel,
        cellSize: CGSize
    ) -> (before: CGRect, after: CGRect)? {
        guard let preview = model.frames.first?.preview else { return nil }
        let imgW = preview.size.width
        let imgH = preview.size.height
        guard imgW > 0, imgH > 0 else { return nil }

        let dispH = cellSize.width * imgH / imgW
        let imgTop = (cellSize.height - dispH) / 2
        let before = CGRect(x: 0, y: imgTop, width: cellSize.width, height: dispH)

        let dispH2 = cellSize.width * imgW / imgH
        let imgTop2 = (cellSize.height - dispH2) / 2
        let after = CGRect(x: 0, y: imgTop2, width: cellSize.width, height: dispH2)

        print("📐 documentsRects | imgSize=\(imgW)×\(imgH) ratio=\(imgW/imgH)")
        print("📐 documentsRects | before: dispH=\(dispH) imgTop=\(imgTop)")
        print("📐 documentsRects | after:  dispH=\(dispH2) imgTop=\(imgTop2)")

        return (before, after)
    }

    private func idCardContentRects(
        model: ScanPreviewModel,
        position: CGPoint,
        cellSize: CGSize
    ) -> (before: CGRect, after: CGRect)? {
        let frameSize = CGSize(width: 171, height: 108)
        let spacing: CGFloat = 8
        let totalH = frameSize.height * 2 + spacing
        let startY = (cellSize.height - totalH) / 2
        let startX = (cellSize.width - frameSize.width) / 2

        let frame1 = CGRect(x: startX, y: startY, width: frameSize.width, height: frameSize.height)
        let frame2 = CGRect(x: startX, y: startY + frameSize.height + spacing, width: frameSize.width, height: frameSize.height)

        // Determine which image the text is over
        let frameIndex: Int
        let imageFrame: CGRect
        if position.y < frame2.minY {
            frameIndex = 0
            imageFrame = frame1
        } else {
            frameIndex = min(1, model.frames.count - 1)
            imageFrame = frame2
        }

        guard model.frames.indices.contains(frameIndex),
              let preview = model.frames[frameIndex].preview else { return nil }

        let imgSize = preview.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }

        let before = aspectFitRect(imageSize: imgSize, in: imageFrame)
        let rotatedSize = CGSize(width: imgSize.height, height: imgSize.width)
        let after = aspectFitRect(imageSize: rotatedSize, in: imageFrame)

        print("📐 idCardRects | position=\(position) → frameIndex=\(frameIndex)")
        print("📐 idCardRects | imageFrame=\(imageFrame)")
        print("📐 idCardRects | imgSize=\(imgSize.width)×\(imgSize.height) rotatedSize=\(rotatedSize.width)×\(rotatedSize.height)")
        print("📐 idCardRects | before=\(before)")
        print("📐 idCardRects | after =\(after)")

        return (before, after)
    }

    private func passportContentRects(
        model: ScanPreviewModel,
        cellSize: CGSize
    ) -> (before: CGRect, after: CGRect)? {
        guard let preview = model.frames.first?.preview else { return nil }
        let imgSize = preview.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }

        let frameSize = CGSize(width: 360, height: 250)
        let frameX = (cellSize.width - frameSize.width) / 2
        let frameY = (cellSize.height - frameSize.height) / 2
        let frame = CGRect(x: frameX, y: frameY, width: frameSize.width, height: frameSize.height)

        let before = aspectFitRect(imageSize: imgSize, in: frame)
        let rotatedSize = CGSize(width: imgSize.height, height: imgSize.width)
        let after = aspectFitRect(imageSize: rotatedSize, in: frame)

        print("📐 passportRects | imgSize=\(imgSize.width)×\(imgSize.height) rotatedSize=\(rotatedSize.width)×\(rotatedSize.height)")
        print("📐 passportRects | passportFrame=\(frame)")
        print("📐 passportRects | before=\(before)")
        print("📐 passportRects | after =\(after)")

        return (before, after)
    }

    private func aspectFitRect(imageSize: CGSize, in frame: CGRect) -> CGRect {
        let scale = min(frame.width / imageSize.width, frame.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
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
