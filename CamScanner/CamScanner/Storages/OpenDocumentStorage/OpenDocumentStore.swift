import Foundation
import CoreData
import Combine
import UIKit

extension Notification.Name {
    static let openDocumentPreviewDidChange = Notification.Name("openDocumentPreviewDidChange")
    static let documentDidChange = Notification.Name("documentDidChange")
}

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

    var signatureItemsPublisher: AnyPublisher<[DocumentSignatureItem], Never> {
        signatureItemsSubject.eraseToAnyPublisher()
    }

    private let previewModelsSubject = CurrentValueSubject<[ScanPreviewModel], Never>([])
    private let textItemsSubject = CurrentValueSubject<[DocumentTextItem], Never>([])
    private let watermarkItemsSubject = CurrentValueSubject<[DocumentWatermarkItem], Never>([])
    private let signatureItemsSubject = CurrentValueSubject<[DocumentSignatureItem], Never>([])

    private let context: NSManagedObjectContext
    private let documentID: UUID
    private let documentRepository: DocumentRepository
    private var cancellables = Set<AnyCancellable>()

    private var frc: NSFetchedResultsController<DocumentEntity>!

    init(
        documentID: UUID,
        context: NSManagedObjectContext,
        documentRepository: DocumentRepository
    ) {
        self.documentID = documentID
        self.context = context
        self.documentRepository = documentRepository
        super.init()
        configureFRC()
        subscribe()
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

    func reloadSignatureItems() {
        let items = (try? documentRepository.fetchSignatureOverlays(documentID: documentID)) ?? []
        signatureItemsSubject.send(items)
    }
}

private extension OpenDocumentStore {
    func subscribe() {
        NotificationCenter.default.publisher(for: .openDocumentPreviewDidChange)
            .compactMap { $0.userInfo?["documentID"] as? UUID }
            .filter { [documentID] changedID in
                changedID == documentID
            }
            .sink { [weak self] _ in
                self?.rebuild()
            }
            .store(in: &cancellables)
    }

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
              let inputModel = try? documentRepository.loadPreviewInputModel(id: id)
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
        reloadSignatureItems()
    }
}

extension OpenDocumentStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuild()
    }
}
