import Foundation
import CoreData
import Combine
import UIKit

final class FolderDocumentStore: NSObject {
    // MARK: - Publishers

    var itemsPublisher: AnyPublisher<[FilesGridItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    var thumbnailsPublisher: AnyPublisher<[ThumbKey: UIImage], Never> {
        thumbnailsSubject.eraseToAnyPublisher()
    }

    // MARK: - State

    private let itemsSubject = CurrentValueSubject<[FilesGridItem], Never>([])
    private let thumbnailsSubject = CurrentValueSubject<[ThumbKey: UIImage], Never>([:])

    private let context = PersistenceController.shared.container.viewContext

    private var documentsFRC: NSFetchedResultsController<DocumentEntity>!

    private var thumbInFlight = Set<ThumbKey>()
    private var rebuildWorkItem: DispatchWorkItem?

    private let folderID: UUID

    init(folderID: UUID) {
        self.folderID = folderID
        super.init()
        configureFRC()
        performFetch()
        rebuild()
    }

    deinit {
        rebuildWorkItem?.cancel()
    }
}

private extension FolderDocumentStore {
    func configureFRC() {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()

        request.sortDescriptors = [
            NSSortDescriptor(key: "lastViewed", ascending: false)
        ]

        request.predicate = NSPredicate(
            format: "folder.id == %@",
            folderID as CVarArg
        )

        documentsFRC = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        documentsFRC.delegate = self
    }

    func performFetch() {
        try? documentsFRC.performFetch()
    }
    
    
    func rebuild() {
        let documents = documentsFRC.fetchedObjects ?? []

        let items: [FilesGridItem] = documents.compactMap {
            guard let id = $0.id else { return nil }

            return .document(
                mapToDocument($0)
            )
        }

        cleanThumbnails(validItems: items)
        itemsSubject.send(items)

        for item in items {
            loadThumbnailsIfNeeded(for: item)
        }
    }
    
    
    func mapToDocument(_ doc: DocumentEntity) -> FileDocumentItem {
        let pages = (doc.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        let first = pages.first?.imagePath
        let second = pages.count > 1 ? pages[1].imagePath : nil

        return FileDocumentItem(
            id: doc.id!,
            folderID: doc.folder?.id,
            title: doc.title,
            documentType: DocumentTypeEnum(rawValue: doc.documentTypeRaw ?? "") ?? .documents,
            createdAt: doc.createdAt,
            pageCount: Int(doc.pageCount),
            isLocked: doc.isLocked,
            lockViaFaceId: doc.lockViaFaceId,
            isFavourite: doc.isFavourite,
            sizeInBytes: doc.cachedSize,
            firstPagePath: first,
            secondPagePath: second,
            thumbnail: nil,
            secondThumbnail: nil,
            passwordHash: doc.passwordHash,
            passwordSalt: doc.passwordSalt
        )
    }
    
    func loadThumbnailsIfNeeded(for item: FilesGridItem) {
        switch item {
        case .document(let doc):
            loadDocumentThumbs(
                docID: doc.id,
                paths: [doc.firstPagePath, doc.secondPagePath]
            )
        case .folder:
            break
        }
    }
    
    private func loadDocumentThumbs(docID: UUID, paths: [String?]) {
        for (idx, path) in paths.prefix(2).enumerated() {
            
            guard let relPath = path, !relPath.isEmpty else { continue }
            
            let key = ThumbKey(docID: docID, pageIndex: idx)
            
            if thumbnailsSubject.value[key] != nil { continue }
            if thumbInFlight.contains(key) { continue }
            
            let url = FileStore.shared.url(forRelativePath: relPath)
            
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            
            thumbInFlight.insert(key)
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                
                let img = FileStore.shared.loadImage(at: url)
                let thumb = img?.downscaled(maxDimension: 364)
                
                DispatchQueue.main.async {
                    
                    var dict = self.thumbnailsSubject.value
                    dict[key] = thumb
                    
                    self.thumbnailsSubject.send(dict)
                    self.thumbInFlight.remove(key)
                }
            }
        }
    }
    
    private func cleanThumbnails(validItems: [FilesGridItem]) {
        let validIDs: Set<UUID> = Set(validItems.flatMap {
            
            switch $0 {
            case .document(let doc):
                return [doc.id]
            case .folder(let folder):
                return folder.previewDocuments.map { $0.id }
            }
        })
        
        var dict = thumbnailsSubject.value
        
        dict.keys
            .filter { !validIDs.contains($0.docID) }
            .forEach { dict[$0] = nil }
        
        if dict != thumbnailsSubject.value {
            thumbnailsSubject.send(dict)
        }
        
        thumbInFlight = thumbInFlight.filter { validIDs.contains($0.docID) }
    }
}

extension FolderDocumentStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuildWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuild()
        }

        rebuildWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.05,
            execute: workItem
        )
    }
}
