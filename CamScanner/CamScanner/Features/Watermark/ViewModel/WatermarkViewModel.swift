import Foundation
import Combine
import UIKit

// MARK: - Editing Session

struct WatermarkEditingSession {
    let watermarkID: UUID
    let initialWidth: CGFloat
    let initialHeight: CGFloat
    let initialCenterX: CGFloat
    let initialCenterY: CGFloat
    let leftEdgeX: CGFloat
    let topEdgeY: CGFloat
    let shouldLockWidth: Bool
}

// MARK: - ViewModel

@MainActor
final class WatermarkViewModel: ObservableObject {
    // MARK: - Published

    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var watermarkItems: [DocumentWatermarkItem] = []
    @Published var selectedWatermarkID: UUID?

    @Published var isSaveEnabled = false
    @Published var bubbleAnchor: WatermarkBubbleAnchor?

    @Published var editingWatermarkID: UUID?
    @Published var editingTextDraft: String = ""

    @Published var shouldShowStyleSheet = false
    @Published var styleDraft: WatermarkStyleDraft = .default

    @Published var didAutoCreate = false

    @Published var placementMode: WatermarkPlacementMode = .single

    // MARK: - Internal

    var isEditingText: Bool { editingWatermarkID != nil }
    var isBubbleFrozen = false

    /// Items to display — in tile mode returns generated tile items, in single mode returns watermarkItems
    var displayItems: [DocumentWatermarkItem] {
        if placementMode == .tile {
            return tileItems
        }
        return watermarkItems
    }

    // MARK: - Private

    private var originalWatermarkItems: [DocumentWatermarkItem] = []
    private var editingSession: WatermarkEditingSession?
    private var currentPageSize: CGSize = .zero

    /// Template item for tile mode (text, style, opacity, rotation)
    private var tileTemplate: TileTemplate = .default

    /// Cached tile items
    @Published private(set) var tileItems: [DocumentWatermarkItem] = []

    private let store: WatermarkStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: WatermarkInputModel) {
        self.store = WatermarkStore(documentID: inputModel.documentID)
        subscribe()
    }
}

// MARK: - Tile Template

private struct TileTemplate: Equatable {
    var text: String
    var fontSize: CGFloat
    var textColorHex: String
    var rotation: CGFloat
    var opacity: CGFloat

    static let `default` = TileTemplate(
        text: "Watermark",
        fontSize: 22,
        textColorHex: "#020202FF",
        rotation: 0,
        opacity: 1.0
    )
}

// MARK: - Public Actions

extension WatermarkViewModel {
    func updateCurrentPageSize(_ size: CGSize) {
        guard size != .zero else { return }
        currentPageSize = size

        if placementMode == .tile {
            regenerateTileItems()
        }
    }

    func clearSelection() {
        selectedWatermarkID = nil
        bubbleAnchor = nil
    }

    func autoCreateIfNeeded() {
        guard !didAutoCreate else { return }
        didAutoCreate = true

        let currentPageItems = watermarkItems.filter { $0.pageIndex == selectedIndex }
        guard currentPageItems.isEmpty else { return }

        guard placementMode == .single else { return }

        let measuredSize = measureDefaultWatermarkSize()

        let item = DocumentWatermarkItem(
            id: UUID(),
            pageIndex: selectedIndex,
            text: "Watermark",
            centerX: 0.5,
            centerY: 0.5,
            width: measuredSize.width,
            height: measuredSize.height,
            rotation: 0,
            opacity: 1.0,
            style: .default
        )

        watermarkItems.append(item)
        selectedWatermarkID = item.id
        startEditingSelectedWatermark()
    }

    func handlePageTap(pageIndex: Int, location: CGPoint, initialSize: CGSize) {
        guard placementMode == .single else { return }

        selectedIndex = pageIndex
        bubbleAnchor = nil

        let item = DocumentWatermarkItem(
            id: UUID(),
            pageIndex: pageIndex,
            text: "Watermark",
            centerX: location.x,
            centerY: location.y,
            width: initialSize.width,
            height: initialSize.height,
            rotation: 0,
            opacity: 1.0,
            style: .default
        )

        watermarkItems.append(item)
        selectedWatermarkID = item.id
    }

    func selectWatermark(_ id: UUID?) {
        guard let id else {
            clearSelection()
            return
        }

        if selectedWatermarkID == id, editingWatermarkID == nil, !shouldShowStyleSheet {
            clearSelection()
            return
        }

        selectedWatermarkID = id
        bubbleAnchor = nil
    }

    func startEditingSelectedWatermark() {
        guard let selectedWatermarkID, currentPageSize != .zero,
              let item = watermarkItems.first(where: { $0.id == selectedWatermarkID }) else { return }

        editingWatermarkID = selectedWatermarkID
        editingTextDraft = item.text
        bubbleAnchor = nil

        let leftEdgeX = item.centerX - item.width / 2
        let topEdgeY = item.centerY - item.height / 2
        let measuredSize = measureTextSize(item.text, fontSize: item.style.fontSize)
        let baseHeightNormalized = measuredSize.height

        editingSession = WatermarkEditingSession(
            watermarkID: selectedWatermarkID,
            initialWidth: item.width,
            initialHeight: item.height,
            initialCenterX: item.centerX,
            initialCenterY: item.centerY,
            leftEdgeX: leftEdgeX,
            topEdgeY: topEdgeY,
            shouldLockWidth: item.height > baseHeightNormalized + 0.001
        )
    }

    func updateEditingDraft(_ text: String, pageSize: CGSize) {
        currentPageSize = pageSize
        editingTextDraft = text

        guard let editingWatermarkID,
              let session = editingSession, session.watermarkID == editingWatermarkID,
              let index = watermarkItems.firstIndex(where: { $0.id == editingWatermarkID }) else { return }

        watermarkItems[index].text = text

        let fontSize = watermarkItems[index].style.fontSize
        let measured = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: pageSize.width
        )

        let leftEdgePt = session.leftEdgeX * pageSize.width
        let availableWidthPt = max(pageSize.width - leftEdgePt, 1)
        let lockedWidthPt = session.initialWidth * pageSize.width

        let measuredAtAvailable = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: availableWidthPt
        )
        let measuredAtLocked = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: lockedWidthPt
        )

        let minHeightPt = measured.height
        let keepLocked = session.shouldLockWidth && measuredAtLocked.height > minHeightPt + 1

        let widthPt: CGFloat
        let measuredHeight: CGFloat

        if keepLocked {
            widthPt = lockedWidthPt
            measuredHeight = measuredAtLocked.height
        } else {
            widthPt = max(measured.width, min(measuredAtAvailable.width, availableWidthPt))
            measuredHeight = measuredAtAvailable.height
        }

        let isMultiline = measuredHeight > minHeightPt + 1
        let heightPt = isMultiline ? max(minHeightPt, measuredHeight) : minHeightPt

        let widthNorm = widthPt / max(pageSize.width, 1)
        let heightNorm = heightPt / max(pageSize.height, 1)
        let newCenterX = session.leftEdgeX + widthNorm / 2
        let newCenterY = session.topEdgeY + heightNorm / 2

        guard watermarkItems[index].width != widthNorm
                || watermarkItems[index].height != heightNorm
                || watermarkItems[index].centerX != newCenterX
                || watermarkItems[index].centerY != newCenterY else { return }

        watermarkItems[index].width = widthNorm
        watermarkItems[index].height = heightNorm
        watermarkItems[index].centerX = newCenterX
        watermarkItems[index].centerY = newCenterY
    }

    func applyTextEditing() {
        guard let editingWatermarkID,
              let index = watermarkItems.firstIndex(where: { $0.id == editingWatermarkID }) else {
            resetEditingState()
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? "Watermark" : trimmed

        watermarkItems[index].text = finalText
        editingTextDraft = finalText
        resetEditingState()
    }

    func cancelTextEditing() {
        resetEditingState()
    }

    func moveWatermark(id: UUID, to center: CGPoint) {
        guard placementMode == .single else { return }
        guard let index = watermarkItems.firstIndex(where: { $0.id == id }) else { return }

        let item = watermarkItems[index]
        let minCX = min(item.width / 2, 0.5)
        let maxCX = max(1 - item.width / 2, 0.5)
        let minCY = min(item.height / 2, 0.5)
        let maxCY = max(1 - item.height / 2, 0.5)

        watermarkItems[index].centerX = min(max(center.x, minCX), maxCX)
        watermarkItems[index].centerY = min(max(center.y, minCY), maxCY)
    }

    func updateSelectedWatermarkStyle(colorHex: String? = nil, fontSize: CGFloat? = nil, rotation: CGFloat? = nil, opacity: CGFloat? = nil) {
        if placementMode == .tile {
            updateTileStyle(colorHex: colorHex, fontSize: fontSize, rotation: rotation, opacity: opacity)
            return
        }

        guard let selectedWatermarkID,
              let index = watermarkItems.firstIndex(where: { $0.id == selectedWatermarkID }) else { return }

        if let colorHex {
            watermarkItems[index].style.textColorHex = colorHex
        }

        if let fontSize {
            watermarkItems[index].style.fontSize = fontSize
            if currentPageSize != .zero {
                reflowWatermarkItem(at: index, pageSize: currentPageSize)
            }
        }

        if let rotation {
            watermarkItems[index].rotation = rotation
        }

        if let opacity {
            watermarkItems[index].opacity = opacity
        }
    }

    func deleteSelectedWatermark() {
        guard let selectedWatermarkID else { return }

        bubbleAnchor = nil
        watermarkItems.removeAll { $0.id == selectedWatermarkID }
        self.selectedWatermarkID = nil
    }

    func deleteAllTileWatermarksOnCurrentPage() {
        tileItems = []
        clearSelection()
        placementMode = .single
        styleDraft = .default
        updateSaveState()
    }

    func openStyleEditor() {
        if placementMode == .tile {
            styleDraft = WatermarkStyleDraft(
                colorHex: tileTemplate.textColorHex.normalizedRGBAHex,
                fontSize: tileTemplate.fontSize,
                rotation: tileTemplate.rotation,
                opacity: tileTemplate.opacity
            )
            shouldShowStyleSheet = true
            return
        }

        guard let selectedWatermarkID,
              let item = watermarkItems.first(where: { $0.id == selectedWatermarkID }) else { return }

        styleDraft = WatermarkStyleDraft(
            colorHex: item.style.textColorHex.normalizedRGBAHex,
            fontSize: item.style.fontSize,
            rotation: item.rotation,
            opacity: item.opacity
        )

        shouldShowStyleSheet = true
    }

    func saveWatermarkItems() {
        let itemsToSave: [DocumentWatermarkItem]
        if placementMode == .tile {
            // Keep existing items on other pages, replace only the current page with tile items
            let otherPageItems = watermarkItems.filter { $0.pageIndex != selectedIndex }
            itemsToSave = otherPageItems + tileItems
        } else {
            itemsToSave = watermarkItems
        }
        try? store.saveWatermarkItems(itemsToSave)
        originalWatermarkItems = itemsToSave
        updateSaveState()
    }

    func updateBubbleAnchor(_ anchor: WatermarkBubbleAnchor?) {
        guard selectedWatermarkID != nil else {
            if bubbleAnchor != nil { bubbleAnchor = nil }
            return
        }
        guard bubbleAnchor != anchor else { return }

        DispatchQueue.main.async { [weak self] in
            self?.bubbleAnchor = anchor
        }
    }

    func updateSelectedIndex(_ index: Int) {
        guard models.indices.contains(index) else { return }
        selectedIndex = index
        selectedWatermarkID = nil
        bubbleAnchor = nil

        if placementMode == .tile {
            regenerateTileItems()
        }
    }

    // MARK: - Placement Mode

    func switchPlacementMode(_ mode: WatermarkPlacementMode) {
        guard mode != placementMode else { return }

        clearSelection()
        editingWatermarkID = nil
        editingTextDraft = ""
        bubbleAnchor = nil

        placementMode = mode

        if mode == .tile {
            // Reset tile template to defaults, then take text from existing item if available
            tileTemplate = .default

            if let firstItem = watermarkItems.first(where: { $0.pageIndex == selectedIndex }) {
                tileTemplate.text = firstItem.text
            }

            // Sync styleDraft with tile template
            styleDraft = WatermarkStyleDraft(
                colorHex: tileTemplate.textColorHex,
                fontSize: tileTemplate.fontSize,
                rotation: tileTemplate.rotation,
                opacity: tileTemplate.opacity
            )

            regenerateTileItems()
        }

        updateSaveState()
    }

    func updateTileText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tileTemplate.text = trimmed
        regenerateTileItems()
        updateSaveState()
    }
}

// MARK: - WatermarkPageDelegate

extension WatermarkViewModel: WatermarkPageDelegate {
    func didTapPage(index: Int, location: CGPoint, initialSize: CGSize) {
        handlePageTap(pageIndex: index, location: location, initialSize: initialSize)
    }

    func didTapWatermark(id: UUID) {
        selectWatermark(id)
    }

    func didMoveWatermark(id: UUID, to center: CGPoint) {
        moveWatermark(id: id, to: center)
    }

    func didChangePageSize(_ size: CGSize) {
        updateCurrentPageSize(size)
    }

    func didChangeEditingText(_ text: String, pageSize: CGSize) {
        updateEditingDraft(text, pageSize: pageSize)
    }

    func didSubmitEditing() {
        applyTextEditing()
    }

    func didStartScroll() {
        clearSelection()
    }

    func didChangeSelectedWatermarkFrame(id: UUID, rect: CGRect?) {
        guard selectedWatermarkID == id, let rect else { return }
        guard !isBubbleFrozen else { return }

        let newAnchor = WatermarkBubbleAnchor(
            watermarkID: id,
            pageIndex: selectedIndex,
            rect: rect
        )

        updateBubbleAnchor(newAnchor)
    }

    func didChangePage(index: Int) {
        updateSelectedIndex(index)
    }
}

// MARK: - Private

private extension WatermarkViewModel {
    func subscribe() {
        store.previewModelsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                guard let self else { return }
                self.models = models
                self.selectedIndex = min(self.selectedIndex, max(models.count - 1, 0))
            }
            .store(in: &cancellables)

        store.watermarkItemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.watermarkItems = items
                self.originalWatermarkItems = items
                self.updateSaveState()
            }
            .store(in: &cancellables)

        $watermarkItems
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSaveState()
            }
            .store(in: &cancellables)
    }

    func updateSaveState() {
        if placementMode == .tile {
            isSaveEnabled = !tileItems.isEmpty && tileItems != originalWatermarkItems
        } else {
            isSaveEnabled = watermarkItems != originalWatermarkItems
        }
    }

    func resetEditingState() {
        editingWatermarkID = nil
        editingTextDraft = ""
        editingSession = nil
    }

    func reflowWatermarkItem(at index: Int, pageSize: CGSize) {
        let item = watermarkItems[index]
        let widthPt = item.width * max(pageSize.width, 1)

        let measured = TextMeasurer.measure(
            text: item.text,
            fontSize: item.style.fontSize,
            maxWidth: widthPt
        )

        let newHeightNorm = measured.height / max(pageSize.height, 1)

        let topEdgeY = item.centerY - item.height / 2
        watermarkItems[index].width = measured.width / max(pageSize.width, 1)
        watermarkItems[index].height = newHeightNorm
        watermarkItems[index].centerY = topEdgeY + newHeightNorm / 2
    }

    // MARK: - Text-fit Sizing

    func measureDefaultWatermarkSize() -> CGSize {
        let pageW = max(currentPageSize.width, 322)
        let pageH = max(currentPageSize.height, 456)

        let measured = TextMeasurer.measure(
            text: "Watermark",
            fontSize: DocumentWatermarkStyle.default.fontSize,
            maxWidth: pageW
        )

        return CGSize(
            width: measured.width / pageW,
            height: measured.height / pageH
        )
    }

    func measureTextSize(_ text: String, fontSize: CGFloat) -> CGSize {
        let pageW = max(currentPageSize.width, 322)
        let pageH = max(currentPageSize.height, 456)

        let measured = TextMeasurer.measure(
            text: text.isEmpty ? " " : text,
            fontSize: fontSize,
            maxWidth: pageW
        )

        return CGSize(
            width: measured.width / pageW,
            height: measured.height / pageH
        )
    }

    // MARK: - Tile Generation

    func updateTileStyle(colorHex: String?, fontSize: CGFloat?, rotation: CGFloat?, opacity: CGFloat?) {
        if let colorHex { tileTemplate.textColorHex = colorHex }
        if let fontSize { tileTemplate.fontSize = fontSize }
        if let rotation { tileTemplate.rotation = rotation }
        if let opacity { tileTemplate.opacity = opacity }
        regenerateTileItems()
        updateSaveState()
    }

    func generateTileItemsForPage(_ pageIndex: Int) -> [DocumentWatermarkItem] {
        guard currentPageSize != .zero else { return [] }

        let pageW = currentPageSize.width
        let pageH = currentPageSize.height

        let measured = TextMeasurer.measure(
            text: tileTemplate.text,
            fontSize: tileTemplate.fontSize,
            maxWidth: pageW * 0.6
        )

        let itemWidthNorm = measured.width / pageW
        let itemHeightNorm = measured.height / pageH

        let spacingX = itemWidthNorm * 0.6
        let spacingY = itemHeightNorm * 1.8

        let overflowFactor: CGFloat = 0.3
        let startX: CGFloat = -overflowFactor
        let startY: CGFloat = -overflowFactor
        let endX: CGFloat = 1.0 + overflowFactor
        let endY: CGFloat = 1.0 + overflowFactor

        let stepX = itemWidthNorm + spacingX
        let stepY = itemHeightNorm + spacingY

        var items: [DocumentWatermarkItem] = []
        var row = 0
        var y = startY

        while y < endY {
            let offsetX = (row % 2 == 0) ? 0 : stepX / 2
            var x = startX + offsetX

            while x < endX {
                let item = DocumentWatermarkItem(
                    id: UUID(),
                    pageIndex: pageIndex,
                    text: tileTemplate.text,
                    centerX: x,
                    centerY: y,
                    width: itemWidthNorm,
                    height: itemHeightNorm,
                    rotation: tileTemplate.rotation,
                    opacity: tileTemplate.opacity,
                    style: DocumentWatermarkStyle(
                        fontSize: tileTemplate.fontSize,
                        lineHeight: 28,
                        letterSpacing: -0.43,
                        textColorHex: tileTemplate.textColorHex,
                        alignment: .left
                    )
                )
                items.append(item)
                x += stepX
            }

            y += stepY
            row += 1
        }

        return items
    }

    func regenerateTileItems() {
        tileItems = generateTileItemsForPage(selectedIndex)
    }
}

// MARK: - String Helper

private extension String {
    var normalizedRGBAHex: String {
        replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }
}
