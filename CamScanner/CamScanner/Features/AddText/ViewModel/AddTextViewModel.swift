import Foundation
import Combine
import UIKit

// MARK: - Editing Session

struct EditingSession {
    let textID: UUID
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
final class AddTextViewModel: ObservableObject {
    // MARK: - Published

    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var textItems: [DocumentTextItem] = []
    @Published var selectedTextID: UUID?

    @Published var isSaveEnabled = false
    @Published var bubbleAnchor: AddTextBubbleAnchor?

    @Published var editingTextID: UUID?
    @Published var editingTextDraft: String = ""

    @Published var shouldShowStyleSheet = false
    @Published var styleDraft: AddTextStyleDraft = .default

    // MARK: - Internal

    var isEditingText: Bool { editingTextID != nil }
    var isBubbleFrozen = false

    // MARK: - Private

    private var originalTextItems: [DocumentTextItem] = []
    private var editingSession: EditingSession?
    private var currentPageSize: CGSize = .zero

    private let store: AddTextStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: AddTextInputModel, dependencies: AppDependencies) {
        self.store = AddTextStore(
            documentID: inputModel.documentID,
            documentRepository: dependencies.documentRepository,
            context: dependencies.persistence.container.viewContext
        )
        subscribe()
    }
}

// MARK: - Public Actions

extension AddTextViewModel {
    func updateCurrentPageSize(_ size: CGSize) {
        guard size != .zero else { return }
        currentPageSize = size
    }

    func clearSelection() {
        selectedTextID = nil
        bubbleAnchor = nil
    }

    func handlePageTap(pageIndex: Int, location: CGPoint, initialSize: CGSize) {
        selectedIndex = pageIndex
        bubbleAnchor = nil

        let item = DocumentTextItem(
            id: UUID(),
            pageIndex: pageIndex,
            text: "Text",
            centerX: location.x,
            centerY: location.y,
            width: initialSize.width,
            height: initialSize.height,
            rotation: 0,
            style: .default
        )

        textItems.append(item)
        selectedTextID = item.id
    }

    func selectText(_ id: UUID?) {
        guard let id else {
            clearSelection()
            return
        }

        if selectedTextID == id, editingTextID == nil, !shouldShowStyleSheet {
            clearSelection()
            return
        }

        selectedTextID = id
        bubbleAnchor = nil
    }

    func startEditingSelectedText() {
        guard let selectedTextID, currentPageSize != .zero,
              let item = textItems.first(where: { $0.id == selectedTextID }) else { return }

        editingTextID = selectedTextID
        editingTextDraft = item.text
        bubbleAnchor = nil

        let leftEdgeX = item.centerX - item.width / 2
        let topEdgeY = item.centerY - item.height / 2
        let baseHeightNormalized = 44.0 / max(currentPageSize.height, 1)

        editingSession = EditingSession(
            textID: selectedTextID,
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

        guard let editingTextID,
              let session = editingSession, session.textID == editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else { return }

        textItems[index].text = text

        let fontSize = textItems[index].style.fontSize
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

        guard textItems[index].width != widthNorm
                || textItems[index].height != heightNorm
                || textItems[index].centerX != newCenterX
                || textItems[index].centerY != newCenterY else { return }

        textItems[index].width = widthNorm
        textItems[index].height = heightNorm
        textItems[index].centerX = newCenterX
        textItems[index].centerY = newCenterY
    }

    func applyTextEditing() {
        guard let editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            resetEditingState()
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? "Text" : trimmed

        textItems[index].text = finalText
        editingTextDraft = finalText
        resetEditingState()
    }

    func cancelTextEditing() {
        resetEditingState()
    }

    func moveText(id: UUID, to center: CGPoint) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let item = textItems[index]
        let minCX = min(item.width / 2, 0.5)
        let maxCX = max(1 - item.width / 2, 0.5)
        let minCY = min(item.height / 2, 0.5)
        let maxCY = max(1 - item.height / 2, 0.5)

        textItems[index].centerX = min(max(center.x, minCX), maxCX)
        textItems[index].centerY = min(max(center.y, minCY), maxCY)
    }

    func resizeText(id: UUID, width: CGFloat, centerX: CGFloat?, pageSize: CGSize) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        currentPageSize = pageSize

        let minWidth: CGFloat = 56 / 322
        textItems[index].width = max(width, minWidth)

        if let centerX {
            textItems[index].centerX = centerX
        }

        reflowTextItem(at: index, pageSize: pageSize)
    }

    func updateSelectedTextStyle(colorHex: String? = nil, fontSize: CGFloat? = nil, rotation: CGFloat? = nil) {
        guard let selectedTextID,
              let index = textItems.firstIndex(where: { $0.id == selectedTextID }) else { return }

        if let colorHex {
            textItems[index].style.textColorHex = colorHex
        }

        if let fontSize {
            textItems[index].style.fontSize = fontSize
            if currentPageSize != .zero {
                reflowTextItem(at: index, pageSize: currentPageSize)
            }
        }

        if let rotation {
            textItems[index].rotation = rotation
        }
    }

    func deleteSelectedText() {
        guard let selectedTextID else { return }

        bubbleAnchor = nil
        textItems.removeAll { $0.id == selectedTextID }
        self.selectedTextID = nil
    }

    func openStyleEditor() {
        guard let selectedTextID,
              let item = textItems.first(where: { $0.id == selectedTextID }) else { return }

        styleDraft = AddTextStyleDraft(
            colorHex: item.style.textColorHex.normalizedRGBAHex,
            fontSize: item.style.fontSize,
            rotation: item.rotation
        )

        shouldShowStyleSheet = true
    }

    func saveTextItems() {
        try? store.saveTextItems(textItems)
        originalTextItems = textItems
        updateSaveState()
    }

    func updateBubbleAnchor(_ anchor: AddTextBubbleAnchor?) {
        guard selectedTextID != nil else {
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
        selectedTextID = nil
        bubbleAnchor = nil
    }
}

// MARK: - AddTextPageDelegate

extension AddTextViewModel: AddTextPageDelegate {
    func didTapPage(index: Int, location: CGPoint, initialSize: CGSize) {
        handlePageTap(pageIndex: index, location: location, initialSize: initialSize)
    }

    func didTapText(id: UUID) {
        selectText(id)
    }

    func didMoveText(id: UUID, to center: CGPoint) {
        moveText(id: id, to: center)
    }

    func didResizeText(id: UUID, width: CGFloat, centerX: CGFloat?, pageSize: CGSize) {
        resizeText(id: id, width: width, centerX: centerX, pageSize: pageSize)
    }

    func didChangePageSize(_ size: CGSize) {
        updateCurrentPageSize(size)
    }

    func didChangeResizeState(isResizing: Bool) {
        isBubbleFrozen = isResizing
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

    func didChangeSelectedTextFrame(id: UUID, rect: CGRect?) {
        guard selectedTextID == id, let rect else { return }
        guard !isBubbleFrozen else { return }

        let newAnchor = AddTextBubbleAnchor(
            textID: id,
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

private extension AddTextViewModel {
    func subscribe() {
        store.previewModelsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                guard let self else { return }
                self.models = models
                self.selectedIndex = min(self.selectedIndex, max(models.count - 1, 0))
            }
            .store(in: &cancellables)

        store.textItemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                self.textItems = items
                self.originalTextItems = items
                self.updateSaveState()
            }
            .store(in: &cancellables)

        $textItems
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSaveState()
            }
            .store(in: &cancellables)
    }

    func updateSaveState() {
        isSaveEnabled = textItems != originalTextItems
    }

    func resetEditingState() {
        editingTextID = nil
        editingTextDraft = ""
        editingSession = nil
    }

    func reflowTextItem(at index: Int, pageSize: CGSize) {
        let item = textItems[index]
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
        textItems[index].height = newHeightNorm
        textItems[index].centerY = topEdgeY + newHeightNorm / 2
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
