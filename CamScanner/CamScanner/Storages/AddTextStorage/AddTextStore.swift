import Foundation
import Combine

final class AddTextStore {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        openDocumentStore.previewModelsPublisher
    }

    var textItemsPublisher: AnyPublisher<[DocumentTextItem], Never> {
        textItemsSubject.eraseToAnyPublisher()
    }

    private let openDocumentStore: OpenDocumentStore
    private let documentRepository = DocumentRepository.shared
    private let documentID: UUID

    private let textItemsSubject = CurrentValueSubject<[DocumentTextItem], Never>([])

    init(documentID: UUID) {
        self.documentID = documentID
        self.openDocumentStore = OpenDocumentStore(documentID: documentID)
        loadTextItems()
    }

    func loadTextItems() {
        let items = (try? documentRepository.fetchTextOverlays(documentID: documentID)) ?? []
        textItemsSubject.send(items)
    }

    func saveTextItems(_ items: [DocumentTextItem]) throws {
        try documentRepository.replaceTextOverlays(
            documentID: documentID,
            items: items
        )
        textItemsSubject.send(items)
    }

    func deleteTextItem(id: UUID) throws {
        try documentRepository.deleteTextOverlay(
            documentID: documentID,
            overlayID: id
        )

        var current = textItemsSubject.value
        current.removeAll { $0.id == id }
        textItemsSubject.send(current)
    }
}
