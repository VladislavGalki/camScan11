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

    /// Placement mode for the CURRENT page
    @Published var placementMode: WatermarkPlacementMode = .single

    // MARK: - Internal

    var isEditingText: Bool { editingWatermarkID != nil }
    var isBubbleFrozen = false

    /// Returns items for ALL pages — single items + tile items merged
    var displayItems: [DocumentWatermarkItem] {
        let tilePageIndices = Set(tileItemsByPage.keys)
        // Single items on pages that DON'T have tiles
        let singleItems = watermarkItems.filter { !tilePageIndices.contains($0.pageIndex) }
        // All tile items from all pages
        let allTileItems = tileItemsByPage.values.flatMap { $0 }
        return singleItems + allTileItems
    }

    /// Whether the current page is in tile mode
    var isCurrentPageTile: Bool {
        tileItemsByPage[selectedIndex] != nil
    }

    // MARK: - Private

    private var originalWatermarkItems: [DocumentWatermarkItem] = []
    private var editingSession: WatermarkEditingSession?
    private var currentPageSize: CGSize = .zero

    /// Per-page tile templates
    private var tileTemplatesByPage: [Int: TileTemplate] = [:]

    /// Per-page tile items
    @Published private(set) var tileItemsByPage: [Int: [DocumentWatermarkItem]] = [:]

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

        if isCurrentPageTile {
            regenerateTileItemsForCurrentPage()
        }
    }

    func clearSelection() {
        selectedWatermarkID = nil
        bubbleAnchor = nil
    }

    func handlePageTap(pageIndex: Int, location: CGPoint, initialSize: CGSize) {
        // Block taps on pages that already have tiles
        guard tileItemsByPage[pageIndex] == nil else { return }
        guard pageIndex == selectedIndex else { return }

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
            style: .default,
            isTile: false
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
        guard let selectedWatermarkID, currentPageSize != .zero else { return }

        let item: DocumentWatermarkItem

        if isCurrentPageTile {
            guard let tileItem = tileItemsByPage[selectedIndex]?.first(where: { $0.id == selectedWatermarkID }) else { return }
            item = tileItem
        } else {
            guard let singleItem = watermarkItems.first(where: { $0.id == selectedWatermarkID }) else { return }
            item = singleItem
        }

        editingWatermarkID = selectedWatermarkID
        editingTextDraft = isCurrentPageTile
            ? (tileTemplatesByPage[selectedIndex]?.text ?? item.text)
            : item.text
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

        if isCurrentPageTile {
            guard let editingWatermarkID,
                  let session = editingSession, session.watermarkID == editingWatermarkID,
                  let index = tileItemsByPage[selectedIndex]?.firstIndex(where: { $0.id == editingWatermarkID }),
                  let item = tileItemsByPage[selectedIndex]?[index] else { return }

            tileItemsByPage[selectedIndex]?[index].text = text

            let measured = TextMeasurer.measure(
                text: text,
                fontSize: item.style.fontSize,
                maxWidth: pageSize.width
            )

            let widthPt = min(measured.width, pageSize.width)
            let heightPt = measured.height

            let widthNorm = widthPt / max(pageSize.width, 1)
            let heightNorm = heightPt / max(pageSize.height, 1)
            let newCenterX = min(
                max(session.leftEdgeX + widthNorm / 2, widthNorm / 2),
                1 - widthNorm / 2
            )
            let newCenterY = session.topEdgeY + heightNorm / 2

            tileItemsByPage[selectedIndex]?[index].width = widthNorm
            tileItemsByPage[selectedIndex]?[index].height = heightNorm
            tileItemsByPage[selectedIndex]?[index].centerX = newCenterX
            tileItemsByPage[selectedIndex]?[index].centerY = newCenterY
            return
        }

        guard let editingWatermarkID,
              let session = editingSession, session.watermarkID == editingWatermarkID,
              let index = watermarkItems.firstIndex(where: { $0.id == editingWatermarkID }) else { return }

        watermarkItems[index].text = text

        let fontSize = watermarkItems[index].style.fontSize

        // Measure at full page width — frame stretches as wide as needed
        let measured = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: pageSize.width
        )

        let widthPt = min(measured.width, pageSize.width)
        let heightPt = measured.height

        let widthNorm = widthPt / max(pageSize.width, 1)
        let heightNorm = heightPt / max(pageSize.height, 1)

        // Keep top edge pinned, recalculate centerX so frame stays within page
        let newCenterX = min(
            max(session.leftEdgeX + widthNorm / 2, widthNorm / 2),
            1 - widthNorm / 2
        )
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
        if isCurrentPageTile {
            guard let editingWatermarkID else {
                resetEditingState()
                return
            }

            let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalText = trimmed.isEmpty ? "Watermark" : trimmed

            if let selectedTileIndex = tileItemsByPage[selectedIndex]?.firstIndex(where: { $0.id == editingWatermarkID }) {
                tileTemplatesByPage[selectedIndex]?.text = finalText
                regenerateTileItemsForCurrentPage(preservingSelectedIndex: selectedTileIndex)
            } else {
                tileTemplatesByPage[selectedIndex]?.text = finalText
                regenerateTileItemsForCurrentPage()
            }

            editingTextDraft = finalText
            updateSaveState()

            resetEditingState()
            return
        }

        guard let editingWatermarkID,
              let index = watermarkItems.firstIndex(where: { $0.id == editingWatermarkID }) else {
            resetEditingState()
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? "Watermark" : trimmed

        let draftBeforeTrim = watermarkItems[index].text
        let currentWidthPt = watermarkItems[index].width * max(currentPageSize.width, 1)

        watermarkItems[index].text = finalText
        editingTextDraft = finalText

        // During live editing the frame already grows to the right size.
        // On submit we should preserve that width instead of snapping back
        // to the pre-edit width, otherwise the watermark visually "shrinks".
        if currentPageSize != .zero {
            if draftBeforeTrim != finalText {
                let reflowWidthPt = max(currentWidthPt, 1)
                let measured = TextMeasurer.measure(
                    text: finalText,
                    fontSize: watermarkItems[index].style.fontSize,
                    maxWidth: reflowWidthPt
                )

                let widthNorm = measured.width / max(currentPageSize.width, 1)
                let heightNorm = measured.height / max(currentPageSize.height, 1)

                watermarkItems[index].width = widthNorm
                watermarkItems[index].height = heightNorm
            }
        } else if let session = editingSession {
            let initialWidthPt = session.initialWidth * currentPageSize.width
            let measured = TextMeasurer.measure(
                text: finalText,
                fontSize: watermarkItems[index].style.fontSize,
                maxWidth: initialWidthPt
            )

            let widthNorm = measured.width / max(currentPageSize.width, 1)
            let heightNorm = measured.height / max(currentPageSize.height, 1)

            watermarkItems[index].width = widthNorm
            watermarkItems[index].height = heightNorm
            watermarkItems[index].centerX = session.leftEdgeX + widthNorm / 2
            watermarkItems[index].centerY = session.topEdgeY + heightNorm / 2
        }

        resetEditingState()
    }

    func cancelTextEditing() {
        resetEditingState()
    }

    func moveWatermark(id: UUID, to center: CGPoint) {
        // Only allow moving single-mode watermarks (not tile items)
        guard !isCurrentPageTile else { return }
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
        if isCurrentPageTile {
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
        tileItemsByPage.removeValue(forKey: selectedIndex)
        tileTemplatesByPage.removeValue(forKey: selectedIndex)
        // Also remove single-mode watermarks on the current page
        watermarkItems.removeAll { $0.pageIndex == selectedIndex }
        clearSelection()
        placementMode = .single
        styleDraft = .default
        updateSaveState()
    }

    func openStyleEditor() {
        // Sync segment control with current page's actual mode
        placementMode = isCurrentPageTile ? .tile : .single

        if isCurrentPageTile, let template = tileTemplatesByPage[selectedIndex] {
            styleDraft = WatermarkStyleDraft(
                colorHex: template.textColorHex.normalizedRGBAHex,
                fontSize: template.fontSize,
                rotation: template.rotation,
                opacity: template.opacity
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
        // Merge: single items on non-tile pages + tile items on tile pages
        let tilePageIndices = Set(tileItemsByPage.keys)
        let singleItems = watermarkItems.filter { !tilePageIndices.contains($0.pageIndex) }
        let allTileItems = tileItemsByPage.values.flatMap { $0 }
        let itemsToSave = singleItems + allTileItems

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

        // Sync placementMode with the page we're navigating to
        placementMode = tileItemsByPage[index] != nil ? .tile : .single
    }

    // MARK: - Placement Mode

    func switchPlacementMode(_ mode: WatermarkPlacementMode) {
        guard mode != placementMode else { return }

        let selectedSingleItem = selectedWatermarkID.flatMap { selectedID in
            watermarkItems.first { $0.id == selectedID && $0.pageIndex == selectedIndex }
        }

        clearSelection()
        editingWatermarkID = nil
        editingTextDraft = ""
        bubbleAnchor = nil

        placementMode = mode

        if mode == .tile {
            // Create tile template for this page, take text from existing single item if available
            var template = TileTemplate.default

            if let selectedSingleItem {
                template.text = selectedSingleItem.text
            } else if let firstItem = watermarkItems.first(where: { $0.pageIndex == selectedIndex }) {
                template.text = firstItem.text
            }

            tileTemplatesByPage[selectedIndex] = template

            // Sync styleDraft with tile template
            styleDraft = WatermarkStyleDraft(
                colorHex: template.textColorHex,
                fontSize: template.fontSize,
                rotation: template.rotation,
                opacity: template.opacity
            )

            regenerateTileItemsForCurrentPage()
        } else {
            // Switching back to single: remove tile data for this page
            tileItemsByPage.removeValue(forKey: selectedIndex)
            tileTemplatesByPage.removeValue(forKey: selectedIndex)
        }

        updateSaveState()
    }

    func updateTileText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tileTemplatesByPage[selectedIndex]?.text = trimmed
        regenerateTileItemsForCurrentPage()
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
                self.restoreFromLoadedItems(items)
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

    func restoreFromLoadedItems(_ items: [DocumentWatermarkItem]) {
        // Separate tile items from single items
        let tileItems = items.filter { $0.isTile }
        let singleItems = items.filter { !$0.isTile }

        watermarkItems = singleItems
        originalWatermarkItems = items

        // Reconstruct tileItemsByPage and tileTemplatesByPage from persisted tile items
        tileItemsByPage = Dictionary(grouping: tileItems, by: \.pageIndex)
        tileTemplatesByPage = [:]

        for (pageIndex, pageItems) in tileItemsByPage {
            guard let first = pageItems.first else { continue }
            tileTemplatesByPage[pageIndex] = TileTemplate(
                text: first.text,
                fontSize: first.style.fontSize,
                textColorHex: first.style.textColorHex,
                rotation: first.rotation,
                opacity: first.opacity
            )
        }

        // Sync placementMode with the current page
        placementMode = tileItemsByPage[selectedIndex] != nil ? .tile : .single
        updateSaveState()
    }

    func updateSaveState() {
        let tilePageIndices = Set(tileItemsByPage.keys)
        let singleItems = watermarkItems.filter { !tilePageIndices.contains($0.pageIndex) }
        let allTileItems = tileItemsByPage.values.flatMap { $0 }
        let currentItems = singleItems + allTileItems
        isSaveEnabled = currentItems != originalWatermarkItems
    }

    func resetEditingState() {
        editingWatermarkID = nil
        editingTextDraft = ""
        editingSession = nil
    }

    func reflowWatermarkItem(at index: Int, pageSize: CGSize) {
        let item = watermarkItems[index]

        // Measure at full page width to get natural single-line or wrapped size
        let measured = TextMeasurer.measure(
            text: item.text,
            fontSize: item.style.fontSize,
            maxWidth: pageSize.width
        )

        let widthNorm = measured.width / max(pageSize.width, 1)
        let heightNorm = measured.height / max(pageSize.height, 1)

        let topEdgeY = item.centerY - item.height / 2
        // Recalculate centerX so frame stays within page bounds
        let newCenterX = min(max(widthNorm / 2, item.centerX), 1 - widthNorm / 2)

        watermarkItems[index].width = widthNorm
        watermarkItems[index].height = heightNorm
        watermarkItems[index].centerX = newCenterX
        watermarkItems[index].centerY = topEdgeY + heightNorm / 2
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
        guard tileTemplatesByPage[selectedIndex] != nil else { return }
        if let colorHex { tileTemplatesByPage[selectedIndex]?.textColorHex = colorHex }
        if let fontSize { tileTemplatesByPage[selectedIndex]?.fontSize = fontSize }
        if let rotation { tileTemplatesByPage[selectedIndex]?.rotation = rotation }
        if let opacity { tileTemplatesByPage[selectedIndex]?.opacity = opacity }
        regenerateTileItemsForCurrentPage()
        updateSaveState()
    }

    func generateTileItemsForPage(_ pageIndex: Int, template: TileTemplate) -> [DocumentWatermarkItem] {
        guard currentPageSize != .zero else { return [] }

        let pageW = currentPageSize.width
        let pageH = currentPageSize.height

        let measured = TextMeasurer.measure(
            text: template.text,
            fontSize: template.fontSize,
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
                    text: template.text,
                    centerX: x,
                    centerY: y,
                    width: itemWidthNorm,
                    height: itemHeightNorm,
                    rotation: template.rotation,
                    opacity: template.opacity,
                    style: DocumentWatermarkStyle(
                        fontSize: template.fontSize,
                        lineHeight: 28,
                        letterSpacing: -0.43,
                        textColorHex: template.textColorHex,
                        alignment: .left
                    ),
                    isTile: true
                )
                items.append(item)
                x += stepX
            }

            y += stepY
            row += 1
        }

        return items
    }

    func regenerateTileItemsForCurrentPage(preservingSelectedIndex selectedTileIndex: Int? = nil) {
        guard let template = tileTemplatesByPage[selectedIndex] else { return }
        let previousItems = tileItemsByPage[selectedIndex] ?? []
        var regeneratedItems = generateTileItemsForPage(selectedIndex, template: template)

        for index in regeneratedItems.indices {
            guard previousItems.indices.contains(index) else { continue }
            let previousID = previousItems[index].id
            let item = regeneratedItems[index]
            regeneratedItems[index] = DocumentWatermarkItem(
                id: previousID,
                pageIndex: item.pageIndex,
                text: item.text,
                centerX: item.centerX,
                centerY: item.centerY,
                width: item.width,
                height: item.height,
                rotation: item.rotation,
                opacity: item.opacity,
                style: item.style,
                isTile: item.isTile
            )
        }

        tileItemsByPage[selectedIndex] = regeneratedItems

        if let selectedTileIndex,
           regeneratedItems.indices.contains(selectedTileIndex) {
            let preservedID = regeneratedItems[selectedTileIndex].id
            selectedWatermarkID = preservedID
            if editingWatermarkID != nil {
                editingWatermarkID = preservedID
            }
        }
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
