import Foundation
import CoreData
import Combine
import UIKit

final class OpenDocumentStore: NSObject {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        previewModelsSubject.eraseToAnyPublisher()
    }

    private let previewModelsSubject = CurrentValueSubject<[ScanPreviewModel], Never>([])

    private let context = PersistenceController.shared.container.viewContext
    private let documentID: UUID

    private var frc: NSFetchedResultsController<DocumentEntity>!

    init(documentID: UUID) {
        self.documentID = documentID
        super.init()
        configureFRC()
        performFetch()
        rebuild()
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
    }
}

extension OpenDocumentStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuild()
    }
}
