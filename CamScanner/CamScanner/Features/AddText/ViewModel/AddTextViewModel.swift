import Foundation
import Combine
import UIKit

@MainActor
final class AddTextViewModel: ObservableObject {
    // MARK: - Published

    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var textItems: [DocumentTextItem] = []
    @Published var selectedTextID: UUID?

    @Published var isSaveEnabled = false
    
    @Published var shouldFreezeBubbleAnchor = false
    @Published var bubbleAnchor: AddTextBubbleAnchor?

    @Published var editingTextID: UUID?
    @Published var editingTextDraft: String = ""
    
    @Published var shouldShowStyleSheet = false
    @Published var styleDraft: AddTextStyleDraft = .default

    // MARK: - Private
    
    private var originalTextItems: [DocumentTextItem] = []

    private let store: AddTextStore
    private var textEditingSession: TextEditingSession?
    private var currentPageSize: CGSize = .zero
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: AddTextInputModel) {
        self.store = AddTextStore(documentID: inputModel.documentID)
        subscribe()
    }
}

// MARK: - Public

extension AddTextViewModel {
    var isEditingText: Bool {
        editingTextID != nil
    }
    
    func updateCurrentPageSize(_ pageSize: CGSize) {
        guard pageSize != .zero else { return }
        currentPageSize = pageSize
    }

    func setBubbleAnchorFrozen(_ isFrozen: Bool) {
        shouldFreezeBubbleAnchor = isFrozen
    }

    func updateBubbleAnchor(_ anchor: AddTextBubbleAnchor?) {
        guard selectedTextID != nil else {
            if bubbleAnchor != nil {
                bubbleAnchor = nil
            }
            return
        }

        guard bubbleAnchor != anchor else { return }
        bubbleAnchor = anchor
    }

    func updateSelectedIndex(_ index: Int) {
        guard models.indices.contains(index) else { return }

        selectedIndex = index
        selectedTextID = nil
        bubbleAnchor = nil
    }
    
    func clearSelection() {
        selectedTextID = nil
        bubbleAnchor = nil
    }

    func handlePageTap(
        pageIndex: Int,
        location: CGPoint,
        initialSize: CGSize
    ) {
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

        if selectedTextID == id,
           editingTextID == nil,
           !shouldShowStyleSheet {
            clearSelection()
            return
        }

        selectedTextID = id
        bubbleAnchor = nil
    }

    func startEditingSelectedText() {
        guard let selectedTextID else { return }
        guard currentPageSize != .zero else { return }
        guard let item = textItems.first(where: { $0.id == selectedTextID }) else { return }

        editingTextID = selectedTextID
        editingTextDraft = item.text
        bubbleAnchor = nil

        let leftEdgeX = item.centerX - item.width / 2
        let topEdgeY = item.centerY - item.height / 2

        let baseHeightNormalized = 44.0 / max(currentPageSize.height, 1)
        let shouldLockWidth = item.height > baseHeightNormalized + 0.001

        textEditingSession = TextEditingSession(
            textID: selectedTextID,
            initialWidth: item.width,
            initialHeight: item.height,
            initialCenterX: item.centerX,
            initialCenterY: item.centerY,
            leftEdgeX: leftEdgeX,
            topEdgeY: topEdgeY,
            shouldLockWidth: shouldLockWidth
        )
    }

    func updateEditingDraft(_ text: String, pageSize: CGSize) {
        currentPageSize = pageSize
        editingTextDraft = text

        guard let editingTextID,
              let session = textEditingSession,
              session.textID == editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            return
        }

        textItems[index].text = text

        let fontSize = textItems[index].style.fontSize

        let minWidthPoints: CGFloat = 56
        let minHeightPoints: CGFloat = 44

        let leftEdgePoints = session.leftEdgeX * pageSize.width
        let availableWidthPoints = max(pageSize.width - leftEdgePoints, minWidthPoints)
        let lockedWidthPoints = session.initialWidth * pageSize.width

        let measuredAtAvailableWidth = measuredEditingSize(
            text: text,
            fontSize: fontSize,
            maxWidth: availableWidthPoints
        )

        let measuredAtLockedWidth = measuredEditingSize(
            text: text,
            fontSize: fontSize,
            maxWidth: lockedWidthPoints
        )

        let shouldKeepWidthLocked =
            session.shouldLockWidth &&
            measuredAtLockedWidth.height > minHeightPoints + 1

        let widthPoints: CGFloat
        if shouldKeepWidthLocked {
            widthPoints = lockedWidthPoints
        } else {
            widthPoints = max(
                minWidthPoints,
                min(measuredAtAvailableWidth.width, availableWidthPoints)
            )
        }

        let isMultilineAtCurrentWidth: Bool
        if shouldKeepWidthLocked {
            isMultilineAtCurrentWidth = measuredAtLockedWidth.height > minHeightPoints + 1
        } else {
            isMultilineAtCurrentWidth = measuredAtAvailableWidth.height > minHeightPoints + 1
        }

        let measuredHeight: CGFloat
        if shouldKeepWidthLocked {
            measuredHeight = measuredAtLockedWidth.height
        } else {
            measuredHeight = measuredAtAvailableWidth.height
        }

        let heightPoints = isMultilineAtCurrentWidth
            ? max(minHeightPoints, measuredHeight)
            : minHeightPoints

        let widthNormalized = widthPoints / max(pageSize.width, 1)
        let heightNormalized = heightPoints / max(pageSize.height, 1)

        let newCenterX = session.leftEdgeX + widthNormalized / 2
        let newCenterY = session.topEdgeY + heightNormalized / 2

        guard textItems[index].width != widthNormalized ||
              textItems[index].height != heightNormalized ||
              textItems[index].centerX != newCenterX ||
              textItems[index].centerY != newCenterY else {
            return
        }

        textItems[index].width = widthNormalized
        textItems[index].height = heightNormalized
        textItems[index].centerX = newCenterX
        textItems[index].centerY = newCenterY
    }

    func applyTextEditing() {
        guard let editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            self.editingTextID = nil
            self.editingTextDraft = ""
            self.textEditingSession = nil
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? "Text" : trimmed

        textItems[index].text = finalText
        editingTextDraft = finalText
        self.editingTextID = nil
        self.textEditingSession = nil
    }

    func cancelTextEditing() {
        editingTextID = nil
        editingTextDraft = ""
        textEditingSession = nil
    }

    func moveText(id: UUID, to center: CGPoint) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let item = textItems[index]

        let minCenterX = min(item.width / 2, 0.5)
        let maxCenterX = max(1 - item.width / 2, 0.5)

        let minCenterY = min(item.height / 2, 0.5)
        let maxCenterY = max(1 - item.height / 2, 0.5)

        textItems[index].centerX = min(max(center.x, minCenterX), maxCenterX)
        textItems[index].centerY = min(max(center.y, minCenterY), maxCenterY)
    }

    func resizeText(
        id: UUID,
        width: CGFloat,
        centerX: CGFloat? = nil,
        pageSize: CGSize
    ) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        currentPageSize = pageSize

        let minWidth: CGFloat = 56 / 322
        let clampedWidth = max(width, minWidth)

        textItems[index].width = clampedWidth

        if let centerX {
            textItems[index].centerX = centerX
        }
        
        reflowTextItemIfNeeded(id: id, pageSize: pageSize)
    }
    
    func updateSelectedTextStyle(
        colorHex: String? = nil,
        fontSize: CGFloat? = nil,
        rotation: CGFloat? = nil
    ) {
        guard let selectedTextID,
              let index = textItems.firstIndex(where: { $0.id == selectedTextID }) else { return }

        if let colorHex {
            textItems[index].style.textColorHex = colorHex
        }

        if let fontSize {
            textItems[index].style.fontSize = fontSize

            if currentPageSize != .zero {
                reflowTextItemIfNeeded(id: selectedTextID, pageSize: currentPageSize)
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
            colorHex: normalizedHex(item.style.textColorHex),
            fontSize: item.style.fontSize,
            rotation: item.rotation
        )

        shouldShowStyleSheet = true
    }

    func saveTextItems() {
        do {
            try store.saveTextItems(textItems)
            originalTextItems = textItems
            updateSaveState()
        } catch {
        }
    }
    
    private func updateSaveState() {
        isSaveEnabled = textItems != originalTextItems
    }
}

// MARK: - Subscriptions

private extension AddTextViewModel {
    private func subscribe() {
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
}

// MARK: - Helpers

private extension AddTextViewModel {
    func measuredEditingSize(
        text: String,
        fontSize: CGFloat,
        maxWidth: CGFloat
    ) -> CGSize {
        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8
        let kern: CGFloat = -0.43

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
            .kern: kern,
            .paragraphStyle: paragraph
        ]

        let sourceText = text.isEmpty ? " " : text
        let attributed = NSAttributedString(string: sourceText, attributes: attributes)

        let singleLineRect = attributed.boundingRect(
            with: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let contentIdealWidth = ceil(singleLineRect.width)
        let targetContentWidth = min(contentIdealWidth, max(maxWidth - horizontalInset * 2, 1))

        let wrappedRect = attributed.boundingRect(
            with: CGSize(width: targetContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        let result = CGSize(
            width: targetContentWidth + horizontalInset * 2,
            height: ceil(wrappedRect.height) + verticalInset * 2
        )

        return result
    }

    func reflowTextItemIfNeeded(id: UUID, pageSize: CGSize) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let item = textItems[index]

        let minHeightPoints: CGFloat = 44
        let widthPoints = item.width * max(pageSize.width, 1)

        let measured = measuredEditingSize(
            text: item.text,
            fontSize: item.style.fontSize,
            maxWidth: widthPoints
        )

        let newHeightPoints = max(measured.height, minHeightPoints)
        let newHeightNormalized = newHeightPoints / max(pageSize.height, 1)

        let topEdgeY = item.centerY - item.height / 2
        let newCenterY = topEdgeY + newHeightNormalized / 2

        textItems[index].height = newHeightNormalized
        textItems[index].centerY = newCenterY
    }
    
    func normalizedHex(_ hex: String) -> String {
        hex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
            .withHashPrefixRGBA
    }
}

private struct TextEditingSession {
    let textID: UUID
    let initialWidth: CGFloat
    let initialHeight: CGFloat
    let initialCenterX: CGFloat
    let initialCenterY: CGFloat
    let leftEdgeX: CGFloat
    let topEdgeY: CGFloat
    let shouldLockWidth: Bool
}
