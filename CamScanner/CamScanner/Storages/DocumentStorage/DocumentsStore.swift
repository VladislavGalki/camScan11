import Foundation
import CoreData
import UIKit

struct DocumentListItem: Identifiable, Equatable {
    let id: UUID
    let isLocked: Bool
    let createdAt: Date
    let kind: String
    let idType: String?
    let pageCount: Int
    let rememberedFilter: String?
    let firstPageImagePath: String?
}

import Foundation
import CoreData
import UIKit
import Combine

final class DocumentsStore: NSObject {
    var documentEntitiesPublisher: AnyPublisher<[DocumentEntity], Never> {
        documentEntitiesSubject.eraseToAnyPublisher()
    }
    
    var thumbnailsPublisher: AnyPublisher<[UUID: UIImage], Never> {
        thumbnailsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private state
    
    private let documentEntitiesSubject = CurrentValueSubject<[DocumentEntity], Never>([])
    private let thumbnailsSubject = CurrentValueSubject<[UUID: UIImage], Never>([:])

    private var thumbnailsCache: [UUID: UIImage] = [:]
    
    private let context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private var fetchResultController: NSFetchedResultsController<DocumentEntity>!
    
    private var thumbInFlight = Set<UUID>()
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
        request.returnsObjectsAsFaults = true
        
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
        dict.keys.filter { !validIDs.contains($0) }.forEach { dict[$0] = nil }
        thumbnailsSubject.send(dict)
    }
}

extension DocumentsStore {
    func loadThumbnailIfNeeded(id: UUID, firstPageImagePath: String?) {
        // ✅ если уже есть — ничего не делаем
        if thumbnailsSubject.value[id] != nil { return }
        if thumbInFlight.contains(id) { return }

        guard let relPath = firstPageImagePath, !relPath.isEmpty else { return }

        let url = FileStore.shared.url(forRelativePath: relPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        thumbInFlight.insert(id)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let img = FileStore.shared.loadImage(at: url)
            let thumb = img?.downscaled(maxDimension: 364)

            DispatchQueue.main.async {
                guard let self else { return }
                var dict = self.thumbnailsSubject.value
                dict[id] = thumb
                self.thumbnailsSubject.send(dict)
                self.thumbInFlight.remove(id)
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
            dict[docID] = nil
            thumbnailsSubject.send(dict)
            thumbInFlight.remove(docID)
        }
    }
}

// MARK: - FRC Delegate

extension DocumentsStore: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {
        guard let doc = anObject as? DocumentEntity, let id = doc.id else { return }
        
        switch type {
        case .update, .move:
            changedDocIDs.insert(id)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if !changedDocIDs.isEmpty {
            var dict = thumbnailsSubject.value
            for id in changedDocIDs {
                dict[id] = nil
                thumbInFlight.remove(id)
            }
            thumbnailsSubject.send(dict)
            changedDocIDs.removeAll()
        }

        rebuild()
    }
}
