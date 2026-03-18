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
    }

    func applyTextEditing() {
        guard let editingTextID,
              let index = textItems.firstIndex(where: { $0.id == editingTextID }) else {
            self.editingTextID = nil
            self.editingTextDraft = ""
            return
        }

        let trimmed = editingTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newText = trimmed.isEmpty ? "Text" : trimmed

        textItems[index].text = newText
        self.editingTextID = nil
        self.editingTextDraft = ""
    }

    func cancelTextEditing() {
        editingTextID = nil
        editingTextDraft = ""
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
