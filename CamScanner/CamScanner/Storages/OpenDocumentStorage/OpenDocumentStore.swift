import Foundation
import CoreData
import Combine
import UIKit

final class OpenDocumentStore: NSObject {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        previewModelsSubject.eraseToAnyPublisher()
    }

    var textItemsPublisher: AnyPublisher<[DocumentTextItem], Never> {
        textItemsSubject.eraseToAnyPublisher()
    }

    var watermarkItemsPublisher: AnyPublisher<[DocumentWatermarkItem], Never> {
        watermarkItemsSubject.eraseToAnyPublisher()
    }

    private let previewModelsSubject = CurrentValueSubject<[ScanPreviewModel], Never>([])
    private let textItemsSubject = CurrentValueSubject<[DocumentTextItem], Never>([])
    private let watermarkItemsSubject = CurrentValueSubject<[DocumentWatermarkItem], Never>([])

    private let context = PersistenceController.shared.container.viewContext
    private let documentID: UUID
    private let documentRepository = DocumentRepository.shared

    private var frc: NSFetchedResultsController<DocumentEntity>!

    init(documentID: UUID) {
        self.documentID = documentID
        super.init()
        configureFRC()
        performFetch()
        rebuild()
    }

    func reloadTextItems() {
        let items = (try? documentRepository.fetchTextOverlays(documentID: documentID)) ?? []
        textItemsSubject.send(items)
    }

    func reloadWatermarkItems() {
        let items = (try? documentRepository.fetchWatermarkOverlays(documentID: documentID)) ?? []
        watermarkItemsSubject.send(items)
    }
}

private extension OpenDocumentStore {
    func configureFRC() {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", documentID as CVarArg)
        request.fetchLimit = 1
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastViewed", ascending: false)
        ]

        frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        frc.delegate = self
    }

    func performFetch() {
        try? frc.performFetch()
    }
    
    func rebuild() {
        guard let document = frc.fetchedObjects?.first,
              let id = document.id,
              let inputModel = try? DocumentRepository.shared.loadPreviewInputModel(id: id)
        else {
            previewModelsSubject.send([])
            return
        }

        let models = inputModel.pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: $0.frames
            )
        }

        previewModelsSubject.send(models)
        reloadTextItems()
        reloadWatermarkItems()
    }
}

extension OpenDocumentStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuild()
    }
}
