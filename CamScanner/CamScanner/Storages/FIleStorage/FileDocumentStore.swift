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
    
    // MARK: - Search State
    
    private var searchQuery: String = ""
    private var isSearching: Bool = false
    
    // MARK: - Cache
    
    private var documentsByID: [UUID: DocumentEntity] = [:]
    private var foldersByID: [UUID: FolderEntity] = [:]
    
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
    
    // MARK: - Search
    
    func search(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if query == searchQuery && isSearching { return }

        searchQuery = query
        isSearching = true
        rebuild()
    }
    
    func clearSearch() {
        searchQuery = ""
        isSearching = false
        rebuild()
    }
    
    // MARK: - Find documents
    
    func getDocumentItems(inFolder folderID: UUID) throws -> [FileDocumentItem] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "folder.id == %@", folderID as CVarArg)
        
        let documents = try context.fetch(request)

        return documents.map { mapToDocument($0) }
    }
    
    func fetchUnlockQueueItems(for selectedIDs: Set<UUID>) throws -> [UnlockQueueItem] {
        guard !selectedIDs.isEmpty else { return [] }

        let documentRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        documentRequest.predicate = NSPredicate(format: "id IN %@", selectedIDs as NSSet)
        
        let directDocuments = try context.fetch(documentRequest)
        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id IN %@", selectedIDs as NSSet)
        
        let folders = try context.fetch(folderRequest)
        
        let documentsInFoldersRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        documentsInFoldersRequest.predicate = NSPredicate(format: "folder IN %@", folders)
        
        let documentsInFolders = try context.fetch(documentsInFoldersRequest)
        let allDocuments = Array(Set(directDocuments + documentsInFolders))
        
        let documentItems = allDocuments.map {
            UnlockQueueItem(
                id: $0.id ?? UUID(),
                title: $0.title,
                isLocked: $0.isLocked
            )
        }
        
        return documentItems
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
        log("🔁 REBUILD started | sort: \(currentSortType) | search: \(searchQuery)")
        
        let documents: [DocumentEntity]
        let folders: [FolderEntity]

        if isSearching {
            documents = fetchAllDocuments()
            folders = fetchAllFolders()
        } else {
            documents = documentsFRC.fetchedObjects ?? []
            folders = foldersFRC.fetchedObjects ?? []
        }

        documentsByID = Dictionary(uniqueKeysWithValues: documents.compactMap {
            guard let id = $0.id else { return nil }
            return (id, $0)
        })

        foldersByID = Dictionary(uniqueKeysWithValues: folders.compactMap {
            guard let id = $0.id else { return nil }
            return (id, $0)
        })
        
        var items: [FilesGridItem] = []
        
        let filteredDocuments: [DocumentEntity]
        let filteredFolders: [FolderEntity]
        
        if isSearching {
            filteredDocuments = documents.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery)
            }
            
            filteredFolders = folders.filter {
                ($0.title ?? "")
                    .localizedCaseInsensitiveContains(searchQuery)
            }
            
        } else {
            filteredDocuments = documents
            filteredFolders = folders
        }
        
        // MARK: - Folders
        
        if currentFolderID == nil && (isSearching || currentSortType != .starred) {
            for folder in filteredFolders {
                guard let id = folder.id else { continue }
                
                if !isSearching && currentSortType == .locked && !folder.isLocked {
                    continue
                }
                
                let docs = (folder.documents as? Set<DocumentEntity>) ?? []
                
                let previewDocs = docs
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(4)
                    .compactMap { mapToPreview($0) }
                
                let item = FileFolderItem(
                    id: id,
                    title: folder.title ?? "Folder",
                    createdAt: folder.createdAt,
                    isLocked: folder.isLocked,
                    lockViaFaceId: folder.lockViaFaceId,
                    documentsCount: docs.count,
                    previewDocuments: previewDocs,
                    passwordHash: folder.passwordHash,
                    passwordSalt: folder.passwordSalt
                )
                
                items.append(.folder(item))
            }
        }
        
        // MARK: - Documents
        for doc in filteredDocuments {
            guard let _ = doc.id else { continue }
            
            if !isSearching {
                if currentFolderID == nil {
                    if doc.folder != nil { continue }
                } else {
                    if doc.folder?.id != currentFolderID { continue }
                }
            }
            
            items.append(.document(mapToDocument(doc)))
        }
        
        let sorted: [FilesGridItem]

        if isSearching {
            sorted = items.sorted { createdAt($0) > createdAt($1) }
        } else {
            sorted = items.sorted(by: globalComparator)
        }
        
        cleanThumbnails(validItems: sorted)
        
        itemsSubject.send(sorted)
        
        for item in sorted {
            loadThumbnailsIfNeeded(for: item)
        }
        
        log("🔁 REBUILD finished | items: \(sorted.count)")
    }
    
    private func fetchAllDocuments() -> [DocumentEntity] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.sortDescriptors = []
        return (try? context.fetch(request)) ?? []
    }

    private func fetchAllFolders() -> [FolderEntity] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.sortDescriptors = []
        return (try? context.fetch(request)) ?? []
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
            return documentsByID[doc.id]?.lastViewed ?? .distantPast

        case .folder(let folder):
            return foldersByID[folder.id]?.lastViewed ?? .distantPast
        }
    }
    
    private func createdAt(_ item: FilesGridItem) -> Date {
        switch item {
        case .document(let doc):
            return documentsByID[doc.id]?.createdAt ?? doc.createdAt
        case .folder(let folder):
            return foldersByID[folder.id]?.createdAt ?? folder.createdAt
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
            secondThumbnail: nil,
            passwordHash: doc.passwordHash,
            passwordSalt: doc.passwordSalt
        )
    }
}

// MARK: - Thumbnails

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

// MARK: - FRC Delegate

extension FileDocumentStore: NSFetchedResultsControllerDelegate {
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
