import Foundation
import CoreData
import UIKit
import Combine

struct DocumentListItem: Identifiable, Equatable {
    let id: UUID
    let isLocked: Bool
    let createdAt: Date
    let documentType: DocumentTypeEnum
    let pageCount: Int
    let firstPageImagePath: String?
}

final class HomeDocumentsStore: NSObject {
    var documentEntitiesPublisher: AnyPublisher<[DocumentEntity], Never> {
        documentEntitiesSubject.eraseToAnyPublisher()
    }
    
    var thumbnailsPublisher: AnyPublisher<[ThumbKey: UIImage], Never> {
        thumbnailsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private state
    
    private let documentEntitiesSubject = CurrentValueSubject<[DocumentEntity], Never>([])
    private let thumbnailsSubject = CurrentValueSubject<[ThumbKey: UIImage], Never>([:])
    
    private let context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private var fetchResultController: NSFetchedResultsController<DocumentEntity>!
    
    private var thumbInFlight = Set<ThumbKey>()
    private var changedDocIDs = Set<UUID>()
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        bootstrap()
        performFetchDocuments()
    }
    
    private func bootstrap() {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        request.fetchLimit = 4
        request.fetchBatchSize = 4

        fetchResultController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        fetchResultController.delegate = self
    }
    
    private func performFetchDocuments() {
        do {
            try fetchResultController.performFetch()
            rebuild()
        } catch {
            print("Fetch error:", error)
        }
    }
    
    private func rebuild() {
        let docs = fetchResultController.fetchedObjects ?? []
        documentEntitiesSubject.send(docs)

        let validIDs = Set(docs.compactMap { $0.id })

        var dict = thumbnailsSubject.value
        dict.keys
            .filter { !validIDs.contains($0.docID) }
            .forEach { dict[$0] = nil }
        
        thumbnailsSubject.send(dict)
        thumbInFlight = thumbInFlight.filter { validIDs.contains($0.docID) }
    }
}

extension HomeDocumentsStore {
    func loadThumbnailsIfNeeded(docID: UUID, pagePaths: [String?]) {
        for (idx, path) in pagePaths.prefix(2).enumerated() {
            guard let relPath = path, !relPath.isEmpty else { continue }

            let key = ThumbKey(docID: docID, pageIndex: idx)

            if thumbnailsSubject.value[key] != nil { continue }
            if thumbInFlight.contains(key) { continue }

            let url = FileStore.shared.url(forRelativePath: relPath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            thumbInFlight.insert(key)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let img = FileStore.shared.loadImage(at: url)
                let thumb = img?.downscaled(maxDimension: 364)

                DispatchQueue.main.async {
                    guard let self else { return }
                    var dict = self.thumbnailsSubject.value
                    dict[key] = thumb
                    self.thumbnailsSubject.send(dict)
                    self.thumbInFlight.remove(key)
                }
            }
        }
    }
    
    func delete(docID: UUID) throws {
        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", docID as CVarArg)
        req.fetchLimit = 1

        if let doc = try context.fetch(req).first {
            FileStore.shared.deleteDocumentFolder(docID: docID)

            context.delete(doc)
            try context.save()

            var dict = thumbnailsSubject.value
            dict.keys
                .filter { $0.docID == docID }
                .forEach { dict[$0] = nil }
            
            thumbnailsSubject.send(dict)
            thumbInFlight = thumbInFlight.filter { $0.docID != docID }
        }
    }
}

// MARK: - FRC Delegate

extension HomeDocumentsStore: NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        guard let doc = anObject as? DocumentEntity, let id = doc.id else { return }
        
        switch type {
        case .insert, .delete, .update, .move:
            changedDocIDs.insert(id)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if !changedDocIDs.isEmpty {
            var dict = thumbnailsSubject.value
            
            for id in changedDocIDs {
                dict.keys
                    .filter { $0.docID == id }
                    .forEach { dict[$0] = nil }

                thumbInFlight = thumbInFlight.filter { $0.docID != id }
            }
            
            thumbnailsSubject.send(dict)
            changedDocIDs.removeAll()
        }

        rebuild()
    }
}
