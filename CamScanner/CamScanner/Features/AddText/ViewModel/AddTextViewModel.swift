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

    @Published var shouldFreezeBubbleAnchor = false
    @Published var bubbleAnchor: AddTextBubbleAnchor?

    @Published var editingTextID: UUID?
    @Published var editingTextDraft: String = ""
    @Published var shouldShowStyleStub = false

    // MARK: - Private

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
    func updateCurrentPageSize(_ pageSize: CGSize) {
        guard pageSize != .zero else { return }
        currentPageSize = pageSize

        print("""
        📐 UPDATE CURRENT PAGE SIZE
        pageSize: \(pageSize)
        """)
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

        print("""
        📄 UPDATE SELECTED INDEX
        selectedIndex: \(selectedIndex)
        """)
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

        print("""
        ➕ HANDLE PAGE TAP
        pageIndex: \(pageIndex)
        location: \(location)
        initialSize: \(initialSize)
        createdItemID: \(item.id)
        createdWidth: \(item.width)
        createdHeight: \(item.height)
        """)
    }

    func selectText(_ id: UUID?) {
        selectedTextID = id
        bubbleAnchor = nil

        print("""
        🎯 SELECT TEXT
        selectedTextID: \(String(describing: selectedTextID))
        """)
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

        print("""
        🟩 START EDIT
        selectedTextID: \(selectedTextID)
        item.text: \(item.text)
        item.width: \(item.width)
        item.height: \(item.height)
        item.centerX: \(item.centerX)
        item.centerY: \(item.centerY)
        currentPageSize: \(currentPageSize)
        leftEdgeX: \(leftEdgeX)
        topEdgeY: \(topEdgeY)
        shouldLockWidth: \(shouldLockWidth)
        editingTextDraft: \(editingTextDraft)
        """)
    }

    func updateEditingDraft(_ text: String, pageSize: CGSize) {
        let previousDraft = editingTextDraft
        currentPageSize = pageSize
        editingTextDraft = text

        print("""
        🟦 VM UPDATE EDIT DRAFT
        incomingText: \(text)
        incomingCount: \(text.count)
        editingTextID: \(String(describing: editingTextID))
        currentDraft(before): \(previousDraft)
        currentDraft(after): \(editingTextDraft)
        pageSize: \(pageSize)
        """)

        guard let editingTextID,
              let session = textEditingSession,
              session.textID == editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            print("""
            🟥 VM UPDATE EDIT DRAFT ABORT
            reason: missing editing session or item
            editingTextID: \(String(describing: editingTextID))
            hasSession: \(textEditingSession != nil)
            """)
            return
        }

        textItems[index].text = text

        let fontSize = textItems[index].style.fontSize

        let minWidthPoints = session.initialWidth * pageSize.width
        let minHeightPoints = session.initialHeight * pageSize.height

        let leftEdgePoints = session.leftEdgeX * pageSize.width
        let availableWidthPoints = max(pageSize.width - leftEdgePoints, minWidthPoints)

        let lockedWidthPoints = session.initialWidth * pageSize.width

        let measurementWidth: CGFloat = session.shouldLockWidth
            ? lockedWidthPoints
            : availableWidthPoints

        let measuredSize = measuredEditingSize(
            text: text,
            fontSize: fontSize,
            maxWidth: measurementWidth
        )

        let widthPoints: CGFloat
        if session.shouldLockWidth {
            widthPoints = lockedWidthPoints
        } else {
            widthPoints = max(lockedWidthPoints, min(measuredSize.width, availableWidthPoints))
        }

        let hitMaxWidth = session.shouldLockWidth || widthPoints >= availableWidthPoints - 0.5

        let heightPoints = hitMaxWidth
            ? max(minHeightPoints, measuredSize.height)
            : minHeightPoints

        let widthNormalized = widthPoints / max(pageSize.width, 1)
        let heightNormalized = heightPoints / max(pageSize.height, 1)

        let newCenterX = session.leftEdgeX + widthNormalized / 2
        let newCenterY = session.topEdgeY + heightNormalized / 2

        print("""
        🟦 VM EDIT GEOMETRY CALC
        session.initialWidth: \(session.initialWidth)
        session.initialHeight: \(session.initialHeight)
        session.leftEdgeX: \(session.leftEdgeX)
        session.topEdgeY: \(session.topEdgeY)
        session.shouldLockWidth: \(session.shouldLockWidth)

        minWidthPoints: \(minWidthPoints)
        minHeightPoints: \(minHeightPoints)
        leftEdgePoints: \(leftEdgePoints)
        availableWidthPoints: \(availableWidthPoints)
        lockedWidthPoints: \(lockedWidthPoints)
        measurementWidth: \(measurementWidth)
        measuredSize: \(measuredSize)

        widthPoints: \(widthPoints)
        heightPoints: \(heightPoints)
        widthNormalized: \(widthNormalized)
        heightNormalized: \(heightNormalized)
        newCenterX: \(newCenterX)
        newCenterY: \(newCenterY)
        """)

        guard textItems[index].width != widthNormalized ||
              textItems[index].height != heightNormalized ||
              textItems[index].centerX != newCenterX ||
              textItems[index].centerY != newCenterY else {
            print("""
            🟨 VM UPDATE EDIT DRAFT SKIP APPLY
            reason: geometry unchanged
            """)
            return
        }

        textItems[index].width = widthNormalized
        textItems[index].height = heightNormalized
        textItems[index].centerX = newCenterX
        textItems[index].centerY = newCenterY

        print("""
        🟦 VM UPDATE EDIT LAYOUT RESULT
        storedText: \(textItems[index].text)
        width: \(textItems[index].width)
        height: \(textItems[index].height)
        centerX: \(textItems[index].centerX)
        centerY: \(textItems[index].centerY)
        """)
    }

    func applyTextEditing() {
        guard let editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            self.editingTextID = nil
            self.editingTextDraft = ""
            self.textEditingSession = nil

            print("""
            ✅ APPLY TEXT EDITING ABORT
            reason: missing editing item
            """)
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = trimmed.isEmpty ? "Text" : trimmed

        textItems[index].text = finalText
        editingTextDraft = finalText
        self.editingTextID = nil
        self.textEditingSession = nil

        print("""
        ✅ APPLY TEXT EDITING
        finalText: \(finalText)
        finalWidth: \(textItems[index].width)
        finalHeight: \(textItems[index].height)
        finalCenterX: \(textItems[index].centerX)
        finalCenterY: \(textItems[index].centerY)
        """)
    }

    func cancelTextEditing() {
        editingTextID = nil
        editingTextDraft = ""
        textEditingSession = nil

        print("""
        ❌ CANCEL TEXT EDITING
        """)
    }

    func moveText(id: UUID, to center: CGPoint) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let previousCenter = CGPoint(
            x: textItems[index].centerX,
            y: textItems[index].centerY
        )

        textItems[index].centerX = min(max(center.x, 0), 1)
        textItems[index].centerY = min(max(center.y, 0), 1)

        print("""
        ↔️ MOVE TEXT
        id: \(id)
        previousCenter: \(previousCenter)
        newCenter: \(CGPoint(x: textItems[index].centerX, y: textItems[index].centerY))
        """)
    }

    func resizeText(
        id: UUID,
        width: CGFloat,
        centerX: CGFloat? = nil,
        pageSize: CGSize
    ) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }
        currentPageSize = pageSize

        let previousWidth = textItems[index].width
        let previousHeight = textItems[index].height
        let previousCenterX = textItems[index].centerX
        let previousCenterY = textItems[index].centerY

        let minWidth: CGFloat = 56 / 322
        let clampedWidth = max(width, minWidth)

        textItems[index].width = clampedWidth

        if let centerX {
            textItems[index].centerX = centerX
        }

        print("""
        📏 RESIZE TEXT BEFORE REFLOW
        id: \(id)
        pageSize: \(pageSize)
        incomingWidth: \(width)
        clampedWidth: \(clampedWidth)
        previousWidth: \(previousWidth)
        previousHeight: \(previousHeight)
        previousCenterX: \(previousCenterX)
        previousCenterY: \(previousCenterY)
        updatedCenterX: \(textItems[index].centerX)
        """)
        
        reflowTextItemIfNeeded(id: id, pageSize: pageSize)

        if let updatedIndex = textItems.firstIndex(where: { $0.id == id }) {
            print("""
            📏 RESIZE TEXT AFTER REFLOW
            id: \(id)
            newWidth: \(textItems[updatedIndex].width)
            newHeight: \(textItems[updatedIndex].height)
            newCenterX: \(textItems[updatedIndex].centerX)
            newCenterY: \(textItems[updatedIndex].centerY)
            """)
        }
    }

    func deleteSelectedText() {
        guard let selectedTextID else { return }

        bubbleAnchor = nil
        textItems.removeAll { $0.id == selectedTextID }
        self.selectedTextID = nil

        print("""
        🗑 DELETE TEXT
        deletedID: \(selectedTextID)
        """)
    }

    func openStyleStub() {
        shouldShowStyleStub = true

        print("""
        🎨 OPEN STYLE STUB
        """)
    }

    func saveTextItems() {
        try? store.saveTextItems(textItems)

        print("""
        💾 SAVE TEXT ITEMS
        count: \(textItems.count)
        """)
    }
}

// MARK: - Subscriptions

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
                self?.textItems = items
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

        print("""
        📐 MEASURED EDITING SIZE
        text: \(text)
        fontSize: \(fontSize)
        maxWidth: \(maxWidth)
        singleLineRect: \(singleLineRect)
        wrappedRect: \(wrappedRect)
        result: \(result)
        """)

        return result
    }

    func reflowTextItemIfNeeded(id: UUID, pageSize: CGSize) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let item = textItems[index]
        let previousHeight = item.height
        let previousCenterY = item.centerY
        let widthPoints = item.width * pageSize.width

        let measured = measuredEditingSize(
            text: item.text,
            fontSize: item.style.fontSize,
            maxWidth: widthPoints
        )

        let newHeightPoints = max(measured.height, 44)
        let newHeightNormalized = newHeightPoints / max(pageSize.height, 1)

        let topEdgeY = item.centerY - item.height / 2
        let newCenterY = topEdgeY + newHeightNormalized / 2

        textItems[index].height = newHeightNormalized
        textItems[index].centerY = newCenterY

        print("""
        🔁 REFLOW TEXT ITEM
        id: \(id)
        text: \(item.text)
        pageSize: \(pageSize)
        widthPoints: \(widthPoints)
        measured: \(measured)
        previousHeight: \(previousHeight)
        previousCenterY: \(previousCenterY)
        newHeightNormalized: \(newHeightNormalized)
        newCenterY: \(newCenterY)
        """)
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
