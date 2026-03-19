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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(inputModel: AddTextInputModel) {
        self.store = AddTextStore(documentID: inputModel.documentID)
        subscribe()
    }
}

// MARK: - Public

extension AddTextViewModel {
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
        selectedTextID = id
        bubbleAnchor = nil
    }

    func startEditingSelectedText() {
        guard let selectedTextID,
              let item = textItems.first(where: { $0.id == selectedTextID }) else { return }

        editingTextID = selectedTextID
        editingTextDraft = item.text
        bubbleAnchor = nil

        let leftEdgeX = item.centerX - item.width / 2
        let topEdgeY = item.centerY - item.height / 2

        textEditingSession = TextEditingSession(
            textID: selectedTextID,
            initialWidth: item.width,
            initialHeight: item.height,
            initialCenterX: item.centerX,
            initialCenterY: item.centerY,
            leftEdgeX: leftEdgeX,
            topEdgeY: topEdgeY
        )
    }
    
    func updateEditingDraft(_ text: String, pageSize: CGSize) {
        editingTextDraft = text

        guard let editingTextID,
              let session = textEditingSession,
              session.textID == editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else { return }

        textItems[index].text = text

        let fontSize = textItems[index].style.fontSize

        let minWidthPoints = session.initialWidth * pageSize.width
        let minHeightPoints = session.initialHeight * pageSize.height

        let leftEdgePoints = session.leftEdgeX * pageSize.width
        let availableWidthPoints = max(pageSize.width - leftEdgePoints, minWidthPoints)

        let measuredSize = measuredEditingSize(
            text: text,
            fontSize: fontSize,
            maxWidth: availableWidthPoints
        )

        let widthPoints = max(minWidthPoints, min(measuredSize.width, availableWidthPoints))
        let hitMaxWidth = widthPoints >= availableWidthPoints - 0.5

        let heightPoints = hitMaxWidth
            ? max(minHeightPoints, measuredSize.height)
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
    
    func updateEditingTextLayout(
        measuredSize: CGSize,
        pageSize: CGSize
    ) {
        guard let editingTextID,
              let session = textEditingSession,
              session.textID == editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else { return }

        let minWidthPoints = session.initialWidth * pageSize.width
        let minHeightPoints = session.initialHeight * pageSize.height

        let leftEdgePoints = session.leftEdgeX * pageSize.width
        let availableWidthPoints = max(pageSize.width - leftEdgePoints, minWidthPoints)

        let clampedWidthPoints = min(
            max(measuredSize.width, minWidthPoints),
            availableWidthPoints
        )

        let widthNormalized = clampedWidthPoints / max(pageSize.width, 1)

        let hitMaxWidth = clampedWidthPoints >= availableWidthPoints - 0.5
        let targetHeightPoints = hitMaxWidth
            ? max(measuredSize.height, minHeightPoints)
            : minHeightPoints

        let heightNormalized = targetHeightPoints / max(pageSize.height, 1)

        textItems[index].width = widthNormalized
        textItems[index].height = heightNormalized

        let newCenterX = session.leftEdgeX + widthNormalized / 2
        let newCenterY = session.topEdgeY + heightNormalized / 2

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

        textItems[index].centerX = min(max(center.x, 0), 1)
        textItems[index].centerY = min(max(center.y, 0), 1)
    }

    func resizeText(id: UUID, width: CGFloat, centerX: CGFloat? = nil) {
        guard let index = textItems.firstIndex(where: { $0.id == id }) else { return }

        let minWidth: CGFloat = 56 / 322
        let clampedWidth = max(width, minWidth)

        textItems[index].width = clampedWidth

        if let centerX {
            textItems[index].centerX = centerX
        }
    }

    func deleteSelectedText() {
        guard let selectedTextID else { return }

        bubbleAnchor = nil
        textItems.removeAll { $0.id == selectedTextID }
        self.selectedTextID = nil
    }

    func openStyleStub() {
        shouldShowStyleStub = true
    }

    func saveTextItems() {
        try? store.saveTextItems(textItems)
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

        return CGSize(
            width: targetContentWidth + horizontalInset * 2,
            height: ceil(wrappedRect.height) + verticalInset * 2
        )
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
}
