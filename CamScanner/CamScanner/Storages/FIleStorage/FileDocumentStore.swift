import Foundation
import CoreData
import Combine
import UIKit

final class FileDocumentStore: NSObject {
    var itemsPublisher: AnyPublisher<[FilesGridItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }
    
    var thumbnailsPublisher: AnyPublisher<[ThumbKey: UIImage], Never> {
        thumbnailsSubject.eraseToAnyPublisher()
    }
    
    private let itemsSubject = CurrentValueSubject<[FilesGridItem], Never>([])
    private let thumbnailsSubject = CurrentValueSubject<[ThumbKey: UIImage], Never>([:])
    
    private let context: NSManagedObjectContext =
        PersistenceController.shared.container.viewContext
    
    private var documentsFRC: NSFetchedResultsController<DocumentEntity>!
    private var foldersFRC: NSFetchedResultsController<FolderEntity>!
    
    private var thumbInFlight = Set<ThumbKey>()
    
    private var rebuildWorkItem: DispatchWorkItem?
    
    override init() {
        super.init()
        configureFRC()
        performFetch()
        rebuild()
    }
    
    deinit {
        rebuildWorkItem?.cancel()
    }
    
    private func configureFRC() {
        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        documentsFRC = NSFetchedResultsController(
            fetchRequest: docRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        documentsFRC.delegate = self
        
        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        foldersFRC = NSFetchedResultsController(
            fetchRequest: folderRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        foldersFRC.delegate = self
    }
    
    private func performFetch() {
        try? documentsFRC.performFetch()
        try? foldersFRC.performFetch()
    }
    
    private func rebuild(currentFolderID: UUID? = nil) {
        let documents = documentsFRC.fetchedObjects ?? []
        let folders = foldersFRC.fetchedObjects ?? []
        
        var result: [FilesGridItem] = []
        
        if currentFolderID == nil {
            for folder in folders {
                guard let id = folder.id else { continue }
                
                let docs = (folder.documents as? Set<DocumentEntity>) ?? []
                
                let previewDocs = docs
                    .sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
                    .prefix(4)
                    .compactMap { mapToPreview($0) }
                
                let item = FileFolderItem(
                    id: id,
                    title: folder.title ?? "Folder",
                    createdAt: folder.createdAt ?? Date(),
                    isLocked: folder.isLocked,
                    documentsCount: docs.count,
                    previewDocuments: previewDocs
                )
                
                result.append(.folder(item))
            }
        }
        
        for doc in documents {
            guard let id = doc.id else { continue }
            
            if currentFolderID == nil {
                if doc.folder != nil { continue }
            } else {
                if doc.folder?.id != currentFolderID { continue }
            }
            
            result.append(.document(mapToDocument(doc)))
        }
        
        itemsSubject.send(result)

        let validIDs: Set<UUID> = {
            var ids = Set<UUID>()

            for item in result {
                switch item {
                case .document(let doc):
                    ids.insert(doc.id)

                case .folder(let folder):
                    for preview in folder.previewDocuments {
                        ids.insert(preview.id)
                    }
                }
            }

            return ids
        }()

        var dict = thumbnailsSubject.value
        
        dict.keys
            .filter { !validIDs.contains($0.docID) }
            .forEach { dict[$0] = nil }

        if dict != thumbnailsSubject.value {
            thumbnailsSubject.send(dict)
        }
        
        thumbInFlight = thumbInFlight.filter { validIDs.contains($0.docID) }

        for item in result {
            loadThumbnailsIfNeeded(for: item)
        }
    }
    
    private func mapToPreview(_ doc: DocumentEntity) -> FileDocumentItem {
        mapToDocument(doc)
    }
    
    private func mapToDocument(_ doc: DocumentEntity) -> FileDocumentItem {
        let pages = (doc.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []
        
        let first = pages.first?.imagePath
        let second = pages.count > 1 ? pages[1].imagePath : nil
        let documentType = DocumentTypeEnum(rawValue: doc.documentTypeRaw ?? "") ?? .documents
        
        guard let id = doc.id else { fatalError("Document without id") }
        
        return FileDocumentItem(
            id: id,
            folderID: doc.folder?.id,
            title: configureDocumentFileName(createAt: doc.createdAt, documentType: documentType.title),
            documentType: documentType,
            createdAt: doc.createdAt ?? Date(),
            pageCount: Int(doc.pageCount),
            isLocked: doc.isLocked,
            isFavourite: doc.isFavourite,
            sizeInBytes: doc.cachedSize,
            firstPagePath: first,
            secondPagePath: second,
            thumbnail: nil,
            secondThumbnail: nil
        )
    }
    
    private func configureDocumentFileName(createAt: Date?, documentType: String?) -> String {
        guard let createAt, let documentType else { return "Document" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        
        let dateString = formatter.string(from: createAt)
        let typeString = documentType
        
        return "\(dateString) \(typeString)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}

extension FileDocumentStore {
    func loadThumbnailsIfNeeded(for item: FilesGridItem) {
        switch item {
        case .document(let doc):
            loadDocumentThumbs(
                docID: doc.id,
                paths: [doc.firstPagePath, doc.secondPagePath]
            )
        case .folder(let folder):
            for preview in folder.previewDocuments {
                loadDocumentThumbs(
                    docID: preview.id,
                    paths: [preview.firstPagePath, preview.secondPagePath]
                )
            }
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
                    
                    if dict != self.thumbnailsSubject.value {
                        self.thumbnailsSubject.send(dict)
                    }
                    self.thumbInFlight.remove(key)
                }
            }
        }
    }
}

extension FileDocumentStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>
    ) {
        rebuildWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuild()
        }

        rebuildWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
}
