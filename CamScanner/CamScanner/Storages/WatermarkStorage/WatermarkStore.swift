import Foundation
import CoreData
import Combine

final class WatermarkStore {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        openDocumentStore.previewModelsPublisher
    }

    var watermarkItemsPublisher: AnyPublisher<[DocumentWatermarkItem], Never> {
        watermarkItemsSubject.eraseToAnyPublisher()
    }

    private let openDocumentStore: OpenDocumentStore
    private let documentRepository: DocumentRepository
    private let documentID: UUID

    private let watermarkItemsSubject = CurrentValueSubject<[DocumentWatermarkItem], Never>([])

    init(
        documentID: UUID,
        documentRepository: DocumentRepository,
        context: NSManagedObjectContext
    ) {
        self.documentID = documentID
        self.documentRepository = documentRepository
        self.openDocumentStore = OpenDocumentStore(
            documentID: documentID,
            context: context,
            documentRepository: documentRepository
        )
        loadWatermarkItems()
    }

    func loadWatermarkItems() {
        let items = (try? documentRepository.fetchWatermarkOverlays(documentID: documentID)) ?? []
        watermarkItemsSubject.send(items)
    }

    func saveWatermarkItems(_ items: [DocumentWatermarkItem]) throws {
        try documentRepository.replaceWatermarkOverlays(
            documentID: documentID,
            items: items
        )
        watermarkItemsSubject.send(items)
    }

    func deleteWatermarkItem(id: UUID) throws {
        try documentRepository.deleteWatermarkOverlay(
            documentID: documentID,
            overlayID: id
        )

        var current = watermarkItemsSubject.value
        current.removeAll { $0.id == id }
        watermarkItemsSubject.send(current)
    }
}
