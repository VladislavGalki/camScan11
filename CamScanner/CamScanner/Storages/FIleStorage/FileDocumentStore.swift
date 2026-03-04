import Foundation
import CoreData
import Combine
import UIKit

#if DEBUG
private func log(_ message: String) {
    print("📦 FileStore | \(message)")
}
#else
private func log(_ message: String) {}
#endif

final class FileDocumentStore: NSObject {
    
    // MARK: - Publishers
    
    var itemsPublisher: AnyPublisher<[FilesGridItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }
    
    var thumbnailsPublisher: AnyPublisher<[ThumbKey: UIImage], Never> {
        thumbnailsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - State
    
    private var currentSortType: FilesSortType = .recent
    
    private let itemsSubject = CurrentValueSubject<[FilesGridItem], Never>([])
    private let thumbnailsSubject = CurrentValueSubject<[ThumbKey: UIImage], Never>([:])
    
    private let context = PersistenceController.shared.container.viewContext
    
    private var documentsFRC: NSFetchedResultsController<DocumentEntity>!
    private var foldersFRC: NSFetchedResultsController<FolderEntity>!
    
    private var thumbInFlight = Set<ThumbKey>()
    private var rebuildWorkItem: DispatchWorkItem?
    
    deinit {
        rebuildWorkItem?.cancel()
    }
    
    // MARK: - Bootstrap
    
    func bootstrap(with sortType: FilesSortType) {
        currentSortType = sortType
        configureFRC()
        performFetch()
        rebuild()
    }
    
    func updateSortType(_ type: FilesSortType) {
        guard currentSortType != type else { return }
        currentSortType = type
        
        applySortConfiguration()
        rebuild()
    }
    
    // MARK: - FRC Setup
    
    private func configureFRC() {
        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.sortDescriptors = sortDescriptors(for: currentSortType)
        docRequest.predicate = predicate(for: currentSortType)
        
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
    
    private func applySortConfiguration() {
        let request = documentsFRC.fetchRequest
        request.sortDescriptors = sortDescriptors(for: currentSortType)
        request.predicate = predicate(for: currentSortType)
        
        try? documentsFRC.performFetch()
    }
    
    private func performFetch() {
        try? documentsFRC.performFetch()
        try? foldersFRC.performFetch()
    }
    
    // MARK: - Sorting
    
    private func sortDescriptors(for type: FilesSortType) -> [NSSortDescriptor] {
        switch type {
        case .recent:
            return [
                NSSortDescriptor(key: "lastViewed", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        case .dateCreated:
            return [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        case .size:
            return [
                NSSortDescriptor(key: "cachedSize", ascending: false)
            ]
        case .starred, .locked:
            return [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
        }
    }
    
    private func predicate(for type: FilesSortType) -> NSPredicate? {
        switch type {
        case .starred:
            return NSPredicate(format: "isFavourite == YES")
        case .locked:
            return NSPredicate(format: "isLocked == YES")
        default:
            return nil
        }
    }
    
    // MARK: - Rebuild
    
    private func rebuild(currentFolderID: UUID? = nil) {
        log("🔁 REBUILD started | sort: \(currentSortType)")
        
        let documents = documentsFRC.fetchedObjects ?? []
        let folders = foldersFRC.fetchedObjects ?? []
        
        log("Fetched documents: \(documents.count)")
        log("Fetched folders: \(folders.count)")
        
        var items: [FilesGridItem] = []
        
        if currentFolderID == nil && currentSortType != .starred {
            for folder in folders {
                guard let id = folder.id else { continue }
                
                if currentSortType == .locked && !folder.isLocked {
                    continue
                }
                
                let docs = (folder.documents as? Set<DocumentEntity>) ?? []
                
                let previewDocs = docs
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(4)
                    .compactMap { mapToPreview($0) }
                
                log("Folder \(id) preview count: \(previewDocs.count)")
                
                let item = FileFolderItem(
                    id: id,
                    title: folder.title ?? "Folder",
                    createdAt: folder.createdAt,
                    isLocked: folder.isLocked,
                    documentsCount: docs.count,
                    previewDocuments: previewDocs
                )
                
                items.append(.folder(item))
            }
        }
        
        for doc in documents {
            guard let id = doc.id else { continue }
            
            if currentFolderID == nil {
                if doc.folder != nil { continue }
            } else {
                if doc.folder?.id != currentFolderID { continue }
            }
            
            items.append(.document(mapToDocument(doc)))
        }
        
        let sorted = items.sorted(by: globalComparator)
        
        log("Items after sort: \(sorted.count)")
        
        cleanThumbnails(validItems: sorted)
        
        itemsSubject.send(sorted)
        log("Items sent to UI")
        
        for item in sorted {
            loadThumbnailsIfNeeded(for: item)
        }
        
        log("🔁 REBUILD finished")
    }
    
    // MARK: - Global Comparator
    
    private func globalComparator(_ lhs: FilesGridItem, _ rhs: FilesGridItem) -> Bool {
        switch currentSortType {
            
        case .recent:
            return lastViewed(lhs) > lastViewed(rhs)
            
        case .dateCreated:
            return createdAt(lhs) > createdAt(rhs)
            
        case .size:
            return size(lhs) > size(rhs)
            
        case .locked:
            return isLocked(lhs) && !isLocked(rhs)
            
        case .starred:
            return isFavourite(lhs) && !isFavourite(rhs)
        }
    }
    
    private func lastViewed(_ item: FilesGridItem) -> Date {
        switch item {
        case .document(let doc):
            return documentsFRC.fetchedObjects?
                .first(where: { $0.id == doc.id })?.lastViewed ?? .distantPast
        case .folder(let folder):
            return foldersFRC.fetchedObjects?
                .first(where: { $0.id == folder.id })?.lastViewed ?? .distantPast
        }
    }
    
    private func createdAt(_ item: FilesGridItem) -> Date {
        switch item {
        case .document(let doc):
            return doc.createdAt
        case .folder(let folder):
            return folder.createdAt
        }
    }
    
    private func size(_ item: FilesGridItem) -> Int64 {
        switch item {
        case .document(let doc):
            return doc.sizeInBytes
        case .folder(let folder):
            return Int64(folder.previewDocuments.reduce(0) { $0 + Int($1.sizeInBytes) })
        }
    }
    
    private func isLocked(_ item: FilesGridItem) -> Bool {
        switch item {
        case .document(let doc):
            return doc.isLocked
        case .folder(let folder):
            return folder.isLocked
        }
    }
    
    private func isFavourite(_ item: FilesGridItem) -> Bool {
        switch item {
        case .document(let doc):
            return doc.isFavourite
        case .folder:
            return false
        }
    }
    
    // MARK: - Mapping
    
    private func mapToPreview(_ doc: DocumentEntity) -> FileDocumentItem {
        mapToDocument(doc)
    }
    
    private func mapToDocument(_ doc: DocumentEntity) -> FileDocumentItem {
        let pages = (doc.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []
        
        let first = pages.first?.imagePath
        let second = pages.count > 1 ? pages[1].imagePath : nil
        
        guard let id = doc.id else { fatalError("Document without id") }
        
        return FileDocumentItem(
            id: id,
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
            secondThumbnail: nil
        )
    }
}

// MARK: - Thumbnails

extension FileDocumentStore {
    func loadThumbnailsIfNeeded(for item: FilesGridItem) {
        switch item {
        case .document(let doc):
            loadDocumentThumbs(docID: doc.id, paths: [doc.firstPagePath, doc.secondPagePath])
        case .folder(let folder):
            for preview in folder.previewDocuments {
                loadDocumentThumbs(docID: preview.id, paths: [preview.firstPagePath, preview.secondPagePath])
            }
        }
    }
    
    private func loadDocumentThumbs(docID: UUID, paths: [String?]) {
        for (idx, path) in paths.prefix(2).enumerated() {
            guard let relPath = path, !relPath.isEmpty else {
                log("⚠️ No path for \(docID)")
                continue
            }
            
            let key = ThumbKey(docID: docID, pageIndex: idx)
            
            if thumbnailsSubject.value[key] != nil {
                log("✅ Thumbnail already exists for \(docID)")
                continue
            }
            
            if thumbInFlight.contains(key) {
                log("⏳ Thumbnail in flight for \(docID)")
                continue
            }
            
            let url = FileStore.shared.url(forRelativePath: relPath)
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                log("❌ File not found at path \(url.path)")
                continue
            }
            
            log("🚀 Loading thumbnail for \(docID)")
            
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
                    
                    log("✅ Thumbnail stored for \(docID)")
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
        
        log("🧹 Cleaning thumbnails | validIDs: \(validIDs.count)")
        
        var dict = thumbnailsSubject.value
        let before = dict.count
        
        dict.keys
            .filter { !validIDs.contains($0.docID) }
            .forEach {
                log("❌ Removing thumb for \($0.docID)")
                dict[$0] = nil
            }
        
        if dict != thumbnailsSubject.value {
            thumbnailsSubject.send(dict)
        }
        
        log("Thumbnails before: \(before) | after: \(dict.count)")
        
        thumbInFlight = thumbInFlight.filter { validIDs.contains($0.docID) }
    }
}

// MARK: - FRC Delegate

extension FileDocumentStore: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuildWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuild()
        }
        
        rebuildWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
}
