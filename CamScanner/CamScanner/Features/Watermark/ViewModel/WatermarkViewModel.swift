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

    // MARK: - Internal

    var isEditingText: Bool { editingWatermarkID != nil }
    var isBubbleFrozen = false

    // MARK: - Private

    private var originalWatermarkItems: [DocumentWatermarkItem] = []
    private var editingSession: WatermarkEditingSession?
    private var currentPageSize: CGSize = .zero

    private let store: WatermarkStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: WatermarkInputModel) {
        self.store = WatermarkStore(documentID: inputModel.documentID)
        subscribe()
    }
}

// MARK: - Public Actions

extension WatermarkViewModel {
    func updateCurrentPageSize(_ size: CGSize) {
        guard size != .zero else { return }
        currentPageSize = size
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

        let initialSize = CGSize(
            width: 56 / max(currentPageSize.width, 322),
            height: 44 / max(currentPageSize.height, 456)
        )

        let item = DocumentWatermarkItem(
            id: UUID(),
            pageIndex: selectedIndex,
            text: "Watermark",
            centerX: 0.5,
            centerY: 0.5,
            width: initialSize.width,
            height: initialSize.height,
            rotation: 0,
            opacity: 0.3,
            style: .default
        )

        watermarkItems.append(item)
        selectedWatermarkID = item.id
        startEditingSelectedWatermark()
    }

    func handlePageTap(pageIndex: Int, location: CGPoint, initialSize: CGSize) {
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
            opacity: 0.3,
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
        let baseHeightNormalized = 44.0 / max(currentPageSize.height, 1)

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
        let minWidthPt: CGFloat = 56
        let minHeightPt: CGFloat = 44

        let leftEdgePt = session.leftEdgeX * pageSize.width
        let availableWidthPt = max(pageSize.width - leftEdgePt, minWidthPt)
        let lockedWidthPt = session.initialWidth * pageSize.width

        let measuredAtAvailable = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: availableWidthPt
        )
        let measuredAtLocked = TextMeasurer.measure(
            text: text, fontSize: fontSize, maxWidth: lockedWidthPt
        )

        let keepLocked = session.shouldLockWidth && measuredAtLocked.height > minHeightPt + 1

        let widthPt: CGFloat
        let measuredHeight: CGFloat

        if keepLocked {
            widthPt = lockedWidthPt
            measuredHeight = measuredAtLocked.height
        } else {
            widthPt = max(minWidthPt, min(measuredAtAvailable.width, availableWidthPt))
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

    func openStyleEditor() {
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
        try? store.saveWatermarkItems(watermarkItems)
        originalWatermarkItems = watermarkItems
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
        isSaveEnabled = watermarkItems != originalWatermarkItems
    }

    func resetEditingState() {
        editingWatermarkID = nil
        editingTextDraft = ""
        editingSession = nil
    }

    func reflowWatermarkItem(at index: Int, pageSize: CGSize) {
        let item = watermarkItems[index]
        let minHeightPt: CGFloat = 44
        let widthPt = item.width * max(pageSize.width, 1)

        let measuredHeight = TextMeasurer.measureHeight(
            text: item.text,
            fontSize: item.style.fontSize,
            availableWidth: widthPt
        )

        let newHeightPt = max(measuredHeight, minHeightPt)
        let newHeightNorm = newHeightPt / max(pageSize.height, 1)

        let topEdgeY = item.centerY - item.height / 2
        watermarkItems[index].height = newHeightNorm
        watermarkItems[index].centerY = topEdgeY + newHeightNorm / 2
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
