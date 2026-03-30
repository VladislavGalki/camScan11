import Foundation
import CoreData
import UIKit

final class DocumentRepository {
    static let shared = DocumentRepository(
        context: PersistenceController.shared.container.viewContext
    )
    
    private let passwordCryptoService = PasswordCryptoService.shared
    private let keychainService = KeychainService.shared
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }

    private func notifyDocumentDidChange(_ documentID: UUID) {
        NotificationCenter.default.post(
            name: .documentDidChange,
            object: nil,
            userInfo: ["documentID": documentID]
        )
    }
    
    // MARK: - LOAD
    
    func fetchFolders() -> [FolderEntity] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()

        request.sortDescriptors = [
            NSSortDescriptor(key: "lastViewed", ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    func fetchDocuments(in folderId: UUID) -> [DocumentEntity] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()

        request.predicate = NSPredicate(
            format: "folder.id == %@",
            folderId as CVarArg
        )

        request.sortDescriptors = [
            NSSortDescriptor(key: "lastViewed", ascending: false)
        ]

        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    func loadPreviewInputModel(id: UUID) throws -> ScanPreviewInputModel {
        guard let document = try fetchDocument(id: id) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8001,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let pageGroups = try makePreviewPageGroups(for: document)

        return ScanPreviewInputModel(
            pageGroups: pageGroups
        )
    }
    
    func loadPreviewInputModel(ids: [UUID]) throws -> ScanPreviewInputModel {
        guard !ids.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8002,
                userInfo: [NSLocalizedDescriptionKey: "No documents provided"]
            )
        }

        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids as NSArray)

        let fetchedDocuments = try context.fetch(request)

        let documentsByID: [UUID: DocumentEntity] = Dictionary(
            uniqueKeysWithValues: fetchedDocuments.compactMap { document in
                guard let id = document.id else { return nil }
                return (id, document)
            }
        )

        let orderedDocuments = ids.compactMap { documentsByID[$0] }

        let pageGroups = try orderedDocuments.flatMap {
            try makePreviewPageGroups(for: $0)
        }

        return ScanPreviewInputModel(
            pageGroups: pageGroups
        )
    }
}

// MARK: Documents
extension DocumentRepository {
    @discardableResult
    func saveDocument(
        documentType: DocumentTypeEnum,
        frames: [CapturedFrame],
        folder: FolderEntity? = nil
    ) throws -> UUID {
        let pages = frames.map {
            DocumentPagePayload(
                frame: $0,
                sourceDocumentType: documentType
            )
        }

        return try saveDocument(
            documentType: documentType,
            pages: pages,
            folder: folder,
            containerType: .regular
        )
    }
    
    @discardableResult
    func saveDocument(
        documentType: DocumentTypeEnum,
        pages: [DocumentPagePayload],
        folder: FolderEntity? = nil,
        containerType: DocumentContainerType = .regular
    ) throws -> UUID {
        let docID = UUID()

        let doc = DocumentEntity(context: context)
        doc.id = docID
        doc.createdAt = Date()
        doc.lastViewed = Date()
        doc.documentTypeRaw = documentType.rawValue
        doc.containerTypeRaw = containerType.rawValue
        doc.pageCount = Int16(pages.count)
        doc.folder = folder
        doc.title = configureDocumentFileName(
            createAt: doc.createdAt,
            documentType: documentType.title
        )

        for (index, payload) in pages.enumerated() {
            let frame = payload.frame

            guard
                let original = frame.original,
                let preview = frame.preview
            else { continue }

            let pageID = UUID()

            let displayURL = try FileStore.shared.saveJPEG(
                image: preview,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_display.jpg"
            )

            let originalURL = try FileStore.shared.saveJPEG(
                image: original,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_original.jpg"
            )

            let page = PageEntity(context: context)
            page.id = pageID
            page.index = Int16(index)
            page.imagePath = FileStore.shared.relativePath(fromAbsolute: displayURL)
            page.originalPath = FileStore.shared.relativePath(fromAbsolute: originalURL)
            page.sourceDocumentTypeRaw = payload.sourceDocumentType.rawValue

            page.quadData = frame.quad.flatMap { QuadCodec.encode($0) }
            page.drawingData = frame.drawingData

            if let drawingBase = frame.drawingBase {
                let drawingURL = try FileStore.shared.saveJPEG(
                    image: drawingBase,
                    docID: docID,
                    pageID: pageID,
                    fileName: "\(pageID.uuidString)_drawingBase.jpg"
                )
                page.drawingBasePath = FileStore.shared.relativePath(fromAbsolute: drawingURL)
            }

            page.filterTypeRaw = frame.currentFilter.type.rawValue
            page.filterAdjustment = Double(frame.currentFilter.adjustment)
            page.rotationAngle = Double(frame.currentFilter.rotationAngle)
            page.document = doc
        }

        let totalSize = FileStore.shared.documentFolderSize(docID: docID)
        doc.cachedSize = totalSize

        try context.save()
        return docID
    }
    
    func addPagesToDocument(
        documentID: UUID,
        pages: [DocumentPagePayload]
    ) throws {
        guard !pages.isEmpty else { return }

        guard let document = try fetchDocument(id: documentID) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8003,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let existingPages = (document.pages as? Set<PageEntity>) ?? []
        var nextIndex = (existingPages.map { Int($0.index) }.max() ?? -1) + 1

        for payload in pages {
            let frame = payload.frame

            guard
                let original = frame.original,
                let preview = frame.preview
            else { continue }

            let pageID = UUID()

            let displayURL = try FileStore.shared.saveJPEG(
                image: preview,
                docID: documentID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_display.jpg"
            )

            let originalURL = try FileStore.shared.saveJPEG(
                image: original,
                docID: documentID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_original.jpg"
            )

            let page = PageEntity(context: context)
            page.id = pageID
            page.index = Int16(nextIndex)
            page.imagePath = FileStore.shared.relativePath(fromAbsolute: displayURL)
            page.originalPath = FileStore.shared.relativePath(fromAbsolute: originalURL)
            page.sourceDocumentTypeRaw = payload.sourceDocumentType.rawValue

            page.quadData = frame.quad.flatMap { QuadCodec.encode($0) }
            page.drawingData = frame.drawingData

            if let drawingBase = frame.drawingBase {
                let drawingURL = try FileStore.shared.saveJPEG(
                    image: drawingBase,
                    docID: documentID,
                    pageID: pageID,
                    fileName: "\(pageID.uuidString)_drawingBase.jpg"
                )
                page.drawingBasePath = FileStore.shared.relativePath(fromAbsolute: drawingURL)
            }

            page.filterTypeRaw = frame.currentFilter.type.rawValue
            page.filterAdjustment = Double(frame.currentFilter.adjustment)
            page.rotationAngle = Double(frame.currentFilter.rotationAngle)
            page.document = document

            nextIndex += 1
        }

        document.pageCount = Int16(existingPages.count + pages.count)
        document.lastViewed = Date()

        let totalSize = FileStore.shared.documentFolderSize(docID: documentID)
        document.cachedSize = totalSize

        try context.save()
    }

    func deletePage(
        documentID: UUID,
        at pageIndex: Int
    ) throws {
        guard let document = try fetchDocument(id: documentID) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8004,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let pages = sortedPages(for: document)
        guard pages.indices.contains(pageIndex) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8005,
                userInfo: [NSLocalizedDescriptionKey: "Page not found"]
            )
        }

        let pageToDelete = pages[pageIndex]
        deleteAssets(for: pageToDelete)
        context.delete(pageToDelete)

        for page in pages[(pageIndex + 1)...] {
            page.index -= 1
        }

        shiftOverlayPageIndices(
            in: document,
            deletingPageAt: pageIndex
        )

        document.pageCount = Int16(max(pages.count - 1, 0))
        document.lastViewed = Date()
        document.cachedSize = FileStore.shared.documentFolderSize(docID: documentID)

        try context.save()
    }

    @discardableResult
    func replacePageWithLastAdded(
        documentID: UUID,
        at pageIndex: Int,
        previousPageCount: Int
    ) throws -> Bool {
        guard let document = try fetchDocument(id: documentID) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 8006,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let pages = sortedPages(for: document)
        guard previousPageCount >= 0,
              pages.count > previousPageCount,
              pageIndex >= 0,
              pageIndex < previousPageCount,
              pages.indices.contains(pageIndex)
        else {
            return false
        }

        guard let replacementPage = pages.last else {
            return false
        }

        let targetPage = pages[pageIndex]
        guard targetPage != replacementPage else {
            return false
        }

        deleteAssets(for: targetPage)

        targetPage.imagePath = replacementPage.imagePath
        targetPage.originalPath = replacementPage.originalPath
        targetPage.drawingBasePath = replacementPage.drawingBasePath
        targetPage.drawingData = replacementPage.drawingData
        targetPage.quadData = replacementPage.quadData
        targetPage.sourceDocumentTypeRaw = replacementPage.sourceDocumentTypeRaw
        targetPage.filterTypeRaw = replacementPage.filterTypeRaw
        targetPage.filterAdjustment = replacementPage.filterAdjustment
        targetPage.rotationAngle = replacementPage.rotationAngle

        deleteOverlaysForPage(in: document, pageIndex: pageIndex)

        context.delete(replacementPage)

        document.pageCount = Int16(max(pages.count - 1, 0))
        document.lastViewed = Date()
        document.cachedSize = FileStore.shared.documentFolderSize(docID: documentID)

        try context.save()
        return true
    }

    @discardableResult
    func mergeDocuments(
        ids: [UUID],
        folder: FolderEntity? = nil
    ) throws -> UUID {
        guard !ids.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 7001,
                userInfo: [NSLocalizedDescriptionKey: "No documents to merge"]
            )
        }

        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids as NSArray)

        let fetchedDocuments = try context.fetch(request)

        let documentsByID: [UUID: DocumentEntity] = Dictionary(
            uniqueKeysWithValues: fetchedDocuments.compactMap { document in
                guard let id = document.id else { return nil }
                return (id, document)
            }
        )

        let orderedDocuments: [DocumentEntity] = ids.compactMap { documentsByID[$0] }

        guard !orderedDocuments.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 7002,
                userInfo: [NSLocalizedDescriptionKey: "Documents not found"]
            )
        }

        var mergedPages: [DocumentPagePayload] = []

        for document in orderedDocuments {
            let loadedPages = try loadPages(for: document)

            let pages = loadedPages.map {
                DocumentPagePayload(
                    frame: $0.frame,
                    sourceDocumentType: $0.sourceDocumentType
                )
            }

            mergedPages.append(contentsOf: pages)
        }

        guard !mergedPages.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 7003,
                userInfo: [NSLocalizedDescriptionKey: "No pages to merge"]
            )
        }

        return try saveDocument(
            documentType: .documents,
            pages: mergedPages,
            folder: folder,
            containerType: .merged
        )
    }
    
    func setDocumentFavourite(id: UUID, isFavourite: Bool) throws {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        guard let document = try context.fetch(request).first else { return }
        
        document.isFavourite = isFavourite
        
        try context.save()
    }
    
    func setPassword(id: UUID, pin: String, viaFaceId: Bool) throws -> UUID {
        let salt = passwordCryptoService.generateSalt()
        let hash = passwordCryptoService.hash(pin: pin, salt: salt)
        
        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        docRequest.fetchLimit = 1
        
        if let doc = try context.fetch(docRequest).first {
            doc.passwordSalt = salt
            doc.passwordHash = hash
            doc.lockViaFaceId = viaFaceId
            doc.isLocked = true
            
            try context.save()
            
            keychainService.savePIN(pin, id: id)
            return id
        }
        
        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        folderRequest.fetchLimit = 1
        
        if let folder = try context.fetch(folderRequest).first {
            folder.passwordSalt = salt
            folder.passwordHash = hash
            folder.lockViaFaceId = viaFaceId
            folder.isLocked = true
            
            try context.save()
            
            keychainService.savePIN(pin, id: id)
            return id
        }
        
        throw NSError(
            domain: "DocumentRepository",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Id not found"]
        )
    }
    
    @discardableResult
    func removePassword(id: UUID) throws -> UUID {
        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        docRequest.fetchLimit = 1

        if let doc = try context.fetch(docRequest).first {
            doc.passwordSalt = nil
            doc.passwordHash = nil
            doc.lockViaFaceId = false
            doc.isLocked = false

            try context.save()

            keychainService.deletePIN(id: id)

            return id
        }

        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        folderRequest.fetchLimit = 1

        if let folder = try context.fetch(folderRequest).first {
            folder.passwordSalt = nil
            folder.passwordHash = nil
            folder.lockViaFaceId = false
            folder.isLocked = false

            try context.save()

            keychainService.deletePIN(id: id)

            return id
        }

        throw NSError(
            domain: "DocumentRepository",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Id not found"]
        )
    }
    
    func deleteDocument(id: UUID) throws {
        let documentRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        documentRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        documentRequest.fetchLimit = 1

        if let document = try context.fetch(documentRequest).first {

            if let docID = document.id {
                FileStore.shared.deleteDocumentFolder(docID: docID)
            }

            context.delete(document)
            try context.save()
            return
        }

        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        folderRequest.fetchLimit = 1

        if let folder = try context.fetch(folderRequest).first {

            if let documents = folder.documents as? Set<DocumentEntity> {
                for doc in documents {
                    if let docID = doc.id {
                        FileStore.shared.deleteDocumentFolder(docID: docID)
                    }
                    
                    context.delete(doc)
                }
            }

            context.delete(folder)
            try context.save()
            return
        }
    }
    
    func deleteItems(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }

        let idSet = Set(ids)

        let documentRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        documentRequest.predicate = NSPredicate(format: "id IN %@", Array(idSet))

        let documents = try context.fetch(documentRequest)

        for document in documents {
            if let docID = document.id {
                FileStore.shared.deleteDocumentFolder(docID: docID)
            }

            context.delete(document)
        }

        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id IN %@", Array(idSet))

        let folders = try context.fetch(folderRequest)

        for folder in folders {
            if let documents = folder.documents as? Set<DocumentEntity> {
                for doc in documents {
                    if let docID = doc.id {
                        FileStore.shared.deleteDocumentFolder(docID: docID)
                    }

                    context.delete(doc)
                }
            }

            context.delete(folder)
        }

        try context.save()
    }
    
    func getPasswordData(for id: UUID) throws -> (salt: Data, hash: Data)? {
        if let doc = try fetchDocument(id: id),
           let salt = doc.passwordSalt,
           let hash = doc.passwordHash {
            return (salt, hash)
        }

        if let folder = try fetchFolder(id: id),
           let salt = folder.passwordSalt,
           let hash = folder.passwordHash {
            return (salt, hash)
        }

        return nil
    }
    
    private func configureDocumentFileName(createAt: Date?, documentType: String?) -> String {
        guard let createAt else { return "Document" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        
        return "\(formatter.string(from: createAt)) \(documentType ?? "")"
    }
}

// MARK: - Folder
extension DocumentRepository {
    @discardableResult
    func createFolder(title: String) throws -> UUID {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Folder name cannot be empty"]
            )
        }
        
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", trimmedTitle)
        request.fetchLimit = 1
        
        if let existing = try context.fetch(request).first,
           existing.id != nil {
            throw NSError(
                domain: "DocumentRepository",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Folder with this name already exists"]
            )
        }
        
        let folderID = UUID()
        
        let folder = FolderEntity(context: context)
        folder.id = folderID
        folder.title = trimmedTitle
        folder.createdAt = Date()
        folder.lastViewed = Date()
        folder.cachedSize = 0
        folder.isLocked = false
        
        try context.save()
        
        return folderID
    }
    
    func moveDocumentsToFolder(ids: [UUID], toFolder folderID: UUID?) throws {
        guard !ids.isEmpty else { return }

        let documentRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        documentRequest.predicate = NSPredicate(format: "id IN %@", ids)

        let documents = try context.fetch(documentRequest)

        var folder: FolderEntity?

        if let folderID {
            let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            folderRequest.predicate = NSPredicate(format: "id == %@", folderID as CVarArg)
            folderRequest.fetchLimit = 1

            guard let fetchedFolder = try context.fetch(folderRequest).first else {
                throw NSError(
                    domain: "DocumentRepository",
                    code: 6001,
                    userInfo: [NSLocalizedDescriptionKey: "Folder not found"]
                )
            }

            folder = fetchedFolder
        }

        for doc in documents {
            doc.folder = folder
        }

        try context.save()
    }
    
    func renameDocument(id: UUID, newTitle: String) throws {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespaces)

        guard !trimmedTitle.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "Name cannot be empty"]
            )
        }

        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        docRequest.fetchLimit = 1

        if let document = try context.fetch(docRequest).first {
            let uniqueTitle = try makeUniqueTitle(base: trimmedTitle, excludingID: id)
            document.title = uniqueTitle

            try context.save()
            notifyDocumentDidChange(id)
            return
        }

        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        folderRequest.fetchLimit = 1

        if let folder = try context.fetch(folderRequest).first {
            let uniqueTitle = try makeUniqueTitle(base: trimmedTitle, excludingID: id)
            folder.title = uniqueTitle

            try context.save()
            return
        }
    }
    
    private func makeUniqueTitle(base: String, excludingID: UUID) throws -> String {
        var candidate = base
        var index = 1

        while try titleExists(candidate, excludingID: excludingID) {
            candidate = "\(base)_\(index)"
            index += 1
        }

        return candidate
    }
    
    private func titleExists(_ title: String, excludingID: UUID) throws -> Bool {
        let docRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        docRequest.predicate = NSPredicate(
            format: "title == %@ AND id != %@",
            title,
            excludingID as CVarArg
        )
        docRequest.fetchLimit = 1

        if try context.fetch(docRequest).first != nil {
            return true
        }

        let folderRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        folderRequest.predicate = NSPredicate(
            format: "title == %@ AND id != %@",
            title,
            excludingID as CVarArg
        )
        folderRequest.fetchLimit = 1

        return try context.fetch(folderRequest).first != nil
    }
}

// MARK: - TextOverlays
extension DocumentRepository {
    func fetchTextOverlays(documentID: UUID) throws -> [DocumentTextItem] {
        guard let document = try fetchDocument(id: documentID) else { return [] }

        let overlays = (document.textOverlays as? Set<TextOverlayEntity>) ?? []

        return overlays
            .sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                return $0.createdAt < $1.createdAt
            }
            .map(DocumentTextItem.init(entity:))
    }
    
    func replaceTextOverlays(
        documentID: UUID,
        items: [DocumentTextItem]
    ) throws {
        guard let document = try fetchDocument(id: documentID) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 9101,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let existing = (document.textOverlays as? Set<TextOverlayEntity>) ?? []
        for overlay in existing {
            context.delete(overlay)
        }

        let now = Date()

        for item in items {
            let entity = TextOverlayEntity(context: context)
            entity.id = item.id
            entity.pageIndex = Int16(item.pageIndex)
            entity.text = item.text
            entity.centerX = item.centerX
            entity.centerY = item.centerY
            entity.width = item.width
            entity.height = item.height
            entity.rotation = item.rotation
            entity.fontSize = item.style.fontSize
            entity.textColorHex = item.style.textColorHex
            entity.alignmentRaw = item.style.alignment.rawValue
            entity.createdAt = now
            entity.updatedAt = now
            entity.document = document
        }

        try context.save()
        notifyDocumentDidChange(documentID)
    }
    
    func updateTextOverlayCoordinates(_ items: [DocumentTextItem]) throws {
        var documentIDToNotify: UUID?

        for item in items {
            let request: NSFetchRequest<TextOverlayEntity> = TextOverlayEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else { continue }
            if documentIDToNotify == nil {
                documentIDToNotify = entity.document?.id
            }
            entity.centerX = item.centerX
            entity.centerY = item.centerY
            entity.width = item.width
            entity.height = item.height
            entity.rotation = item.rotation
        }
        try context.save()

        if let documentIDToNotify {
            notifyDocumentDidChange(documentIDToNotify)
        }
    }

    /// Saves rotated text coordinates, page rotation angles **and** the rotated
    /// preview images to disk in a single CoreData transaction so everything
    /// stays in sync on reload.
    func saveRotationState(
        documentID: UUID,
        textItems: [DocumentTextItem],
        watermarkItems: [DocumentWatermarkItem],
        pageIndices: [Int],
        rotationAngleDelta: Double,
        pageImages: [(pageIndex: Int, image: UIImage)]
    ) throws {
        // 1. Update text overlay coordinates
        for item in textItems {
            let request: NSFetchRequest<TextOverlayEntity> = TextOverlayEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else { continue }
            entity.centerX = item.centerX
            entity.centerY = item.centerY
            entity.width = item.width
            entity.height = item.height
            entity.rotation = item.rotation
        }

        // 2. Update watermark overlay coordinates
        for item in watermarkItems {
            let request: NSFetchRequest<WatermarkOverlayEntity> = WatermarkOverlayEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", item.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else { continue }
            entity.centerX = item.centerX
            entity.centerY = item.centerY
            entity.width = item.width
            entity.height = item.height
            entity.rotation = item.rotation
        }

        // 3. Increment page rotation angles + save rotated images to disk
        guard let document = try fetchDocument(id: documentID) else { return }
        let pages = (document.pages as? Set<PageEntity>) ?? []

        for page in pages where pageIndices.contains(Int(page.index)) {
            // Rotation is baked into the saved JPEG, so reset angle to 0.
            // This prevents double-rotation when filter re-renders from displayBase on reload.
            page.rotationAngle = 0

            // Overwrite the display JPEG with the newly rotated preview
            if let entry = pageImages.first(where: { $0.pageIndex == Int(page.index) }),
               let relativePath = page.imagePath {
                let fileURL = FileStore.shared.url(forRelativePath: relativePath)
                if let data = entry.image.jpegData(compressionQuality: 0.92) {
                    try? data.write(to: fileURL, options: [.atomic])
                }
            }
        }

        try context.save()
        notifyDocumentDidChange(documentID)
    }

    func saveErasedPageImage(
        documentID: UUID,
        pageImages: [(pageIndex: Int, image: UIImage)]
    ) throws {
        guard let document = try fetchDocument(id: documentID) else { return }
        let pages = (document.pages as? Set<PageEntity>) ?? []

        for page in pages {
            guard let entry = pageImages.first(where: { $0.pageIndex == Int(page.index) }),
                  let relativePath = page.imagePath else { continue }

            let fileURL = FileStore.shared.url(forRelativePath: relativePath)
            if let data = entry.image.jpegData(compressionQuality: 0.92) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }

        try context.save()
        notifyDocumentDidChange(documentID)
    }

    func saveCropState(
        documentID: UUID,
        pageUpdates: [(pageIndex: Int, frame: CapturedFrame)]
    ) throws {
        guard let document = try fetchDocument(id: documentID) else { return }
        let pages = (document.pages as? Set<PageEntity>) ?? []

        for page in pages {
            guard let update = pageUpdates.first(where: { $0.pageIndex == Int(page.index) }) else { continue }

            if let displayImage = update.frame.preview ?? update.frame.displayBase,
               let relativePath = page.imagePath {
                let fileURL = FileStore.shared.url(forRelativePath: relativePath)
                if let data = displayImage.jpegData(compressionQuality: 0.92) {
                    try? data.write(to: fileURL, options: [.atomic])
                }
            }

            page.quadData = update.frame.quad.flatMap { QuadCodec.encode($0) }
            page.drawingData = nil
            page.drawingBasePath = nil
        }

        try context.save()
        notifyDocumentDidChange(documentID)
    }

    func deleteTextOverlay(
        documentID: UUID,
        overlayID: UUID
    ) throws {
        let request: NSFetchRequest<TextOverlayEntity> = TextOverlayEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "document.id == %@", documentID as CVarArg),
            NSPredicate(format: "id == %@", overlayID as CVarArg)
        ])
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            try context.save()
            notifyDocumentDidChange(documentID)
        }
    }
}

// MARK: - WatermarkOverlays
extension DocumentRepository {
    func fetchWatermarkOverlays(documentID: UUID) throws -> [DocumentWatermarkItem] {
        guard let document = try fetchDocument(id: documentID) else { return [] }

        let overlays = (document.watermarkOverlays as? Set<WatermarkOverlayEntity>) ?? []

        return overlays
            .sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                return $0.createdAt < $1.createdAt
            }
            .map(DocumentWatermarkItem.init(entity:))
    }

    func replaceWatermarkOverlays(
        documentID: UUID,
        items: [DocumentWatermarkItem]
    ) throws {
        guard let document = try fetchDocument(id: documentID) else {
            throw NSError(
                domain: "DocumentRepository",
                code: 9201,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        let existing = (document.watermarkOverlays as? Set<WatermarkOverlayEntity>) ?? []
        for overlay in existing {
            context.delete(overlay)
        }

        let now = Date()

        for item in items {
            let entity = WatermarkOverlayEntity(context: context)
            entity.id = item.id
            entity.pageIndex = Int16(item.pageIndex)
            entity.text = item.text
            entity.centerX = item.centerX
            entity.centerY = item.centerY
            entity.width = item.width
            entity.height = item.height
            entity.rotation = item.rotation
            entity.opacity = item.opacity
            entity.isTile = item.isTile
            entity.fontSize = item.style.fontSize
            entity.textColorHex = item.style.textColorHex
            entity.alignmentRaw = item.style.alignment.rawValue
            entity.createdAt = now
            entity.updatedAt = now
            entity.document = document
        }

        try context.save()
        notifyDocumentDidChange(documentID)
    }

    func deleteWatermarkOverlay(
        documentID: UUID,
        overlayID: UUID
    ) throws {
        let request: NSFetchRequest<WatermarkOverlayEntity> = WatermarkOverlayEntity.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "document.id == %@", documentID as CVarArg),
            NSPredicate(format: "id == %@", overlayID as CVarArg)
        ])
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            context.delete(entity)
            try context.save()
            notifyDocumentDidChange(documentID)
        }
    }
}

// MARK: - Share
extension DocumentRepository {
    func loadShareModel(id: UUID) throws -> ShareInputModel {
        if let document = try fetchDocument(id: id) {
            return try buildShareModel(from: [document])
        }

        if let folder = try fetchFolder(id: id) {
            let docs = (folder.documents as? Set<DocumentEntity>) ?? []
            return try buildShareModel(from: Array(docs))
        }

        throw NSError(
            domain: "DocumentRepository",
            code: 5001,
            userInfo: [NSLocalizedDescriptionKey: "Document or folder not found"]
        )
    }
    
    func loadShareModel(ids: [UUID]) throws -> ShareInputModel {
        guard !ids.isEmpty else {
            throw NSError(
                domain: "DocumentRepository",
                code: 5002,
                userInfo: [NSLocalizedDescriptionKey: "No documents provided"]
            )
        }

        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids as NSArray)

        let fetchedDocuments = try context.fetch(request)

        let documentsByID: [UUID: DocumentEntity] = Dictionary(
            uniqueKeysWithValues: fetchedDocuments.compactMap { document in
                guard let id = document.id else { return nil }
                return (id, document)
            }
        )

        let orderedDocuments = ids.compactMap { documentsByID[$0] }

        return try buildShareModel(from: orderedDocuments)
    }

    private func sortedPages(for document: DocumentEntity) -> [PageEntity] {
        (document.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []
    }

    private func deleteAssets(for page: PageEntity) {
        let relativePaths = [
            page.imagePath,
            page.originalPath,
            page.drawingBasePath
        ]

        for relativePath in relativePaths.compactMap({ $0 }) {
            let url = FileStore.shared.url(forRelativePath: relativePath)
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func shiftOverlayPageIndices(
        in document: DocumentEntity,
        deletingPageAt pageIndex: Int
    ) {
        let textOverlays = (document.textOverlays as? Set<TextOverlayEntity>) ?? []
        for overlay in textOverlays {
            if overlay.pageIndex == Int16(pageIndex) {
                context.delete(overlay)
            } else if overlay.pageIndex > Int16(pageIndex) {
                overlay.pageIndex -= 1
            }
        }

        let watermarkOverlays = (document.watermarkOverlays as? Set<WatermarkOverlayEntity>) ?? []
        for overlay in watermarkOverlays {
            if overlay.pageIndex == Int16(pageIndex) {
                context.delete(overlay)
            } else if overlay.pageIndex > Int16(pageIndex) {
                overlay.pageIndex -= 1
            }
        }
    }

    private func deleteOverlaysForPage(
        in document: DocumentEntity,
        pageIndex: Int
    ) {
        let textOverlays = (document.textOverlays as? Set<TextOverlayEntity>) ?? []
        for overlay in textOverlays where overlay.pageIndex == Int16(pageIndex) {
            context.delete(overlay)
        }

        let watermarkOverlays = (document.watermarkOverlays as? Set<WatermarkOverlayEntity>) ?? []
        for overlay in watermarkOverlays where overlay.pageIndex == Int16(pageIndex) {
            context.delete(overlay)
        }
    }
    
    private func fetchDocument(id: UUID) throws -> DocumentEntity? {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }

    private func fetchFolder(id: UUID) throws -> FolderEntity? {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    private func buildShareModel(from documents: [DocumentEntity]) throws -> ShareInputModel {
        guard let first = documents.first else {
            throw NSError(domain: "DocumentRepository", code: 5002)
        }

        let pageGroups = try documents.flatMap {
            try makePreviewPageGroups(for: $0)
        }

        let pages = pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: $0.frames
            )
        }

        let firstType = DocumentTypeEnum(
            rawValue: first.documentTypeRaw ?? ""
        ) ?? .documents

        var allTextItems: [DocumentTextItem] = []
        var allWatermarkItems: [DocumentWatermarkItem] = []
        for document in documents {
            guard let docID = document.id else { continue }
            let textItems = try fetchTextOverlays(documentID: docID)
            let watermarkItems = try fetchWatermarkOverlays(documentID: docID)
            allTextItems.append(contentsOf: textItems)
            allWatermarkItems.append(contentsOf: watermarkItems)
        }

        return ShareInputModel(
            documentName: first.title,
            documentType: firstType,
            pages: pages,
            textItems: allTextItems,
            watermarkItems: allWatermarkItems
        )
    }
    
    private func loadFrames(for document: DocumentEntity) throws -> [CapturedFrame] {
        try loadPages(for: document).map(\.frame)
    }
    
    private func loadPages(for document: DocumentEntity) throws -> [LoadedDocumentPage] {
        let pages = (document.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        let fallbackType = DocumentTypeEnum(
            rawValue: document.documentTypeRaw ?? ""
        ) ?? .documents

        return pages.compactMap { page in
            guard
                let originalPath = page.originalPath,
                let originalImage = UIImage(
                    contentsOfFile: FileStore.shared
                        .url(forRelativePath: originalPath).path
                )
            else { return nil }

            var frame = CapturedFrame()
            frame.original = originalImage

            if let drawingPath = page.drawingBasePath,
               let drawingImage = UIImage(
                    contentsOfFile: FileStore.shared
                        .url(forRelativePath: drawingPath).path
               ) {
                frame.drawingBase = drawingImage
            }

            frame.drawingData = page.drawingData

            if let quadData = page.quadData {
                frame.quad = QuadCodec.decode(quadData)
            }

            let filterType = DocumentFilterType(
                rawValue: page.filterTypeRaw ?? ""
            ) ?? .original

            let state = FilterState(
                type: filterType,
                adjustment: CGFloat(page.filterAdjustment),
                rotationAngle: CGFloat(page.rotationAngle)
            )

            frame.applyFilter(state)

            if let displayPath = page.imagePath,
               let displayImage = UIImage(
                    contentsOfFile: FileStore.shared
                        .url(forRelativePath: displayPath).path
               ) {
                frame.previewBase = displayImage
            } else {
                frame.previewBase = originalImage
            }

            if let base = frame.previewBase {
                frame.previewBase = ImageCompressionService.shared.compress(
                    base,
                    maxDimension: 1200,
                    quality: 0.90
                )
            }

            frame.displayBase = frame.previewBase
            frame.preview = frame.displayBase

            let sourceType = DocumentTypeEnum(
                rawValue: page.sourceDocumentTypeRaw
            ) ?? fallbackType

            return LoadedDocumentPage(
                frame: frame,
                sourceDocumentType: sourceType
            )
        }
    }
}

// MARK: - Helpers
extension DocumentRepository {
    func fetchDocumentTitle(id: UUID) throws -> String {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let document = try context.fetch(request).first else {
            throw NSError(
                domain: "DocumentRepository",
                code: 9001,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        return document.title
    }

    func fetchDocumentIsLocked(id: UUID) throws -> Bool {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let document = try context.fetch(request).first else {
            throw NSError(
                domain: "DocumentRepository",
                code: 9002,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        return document.isLocked
    }

    func fetchDocumentLockViaFaceId(id: UUID) throws -> Bool {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        guard let document = try context.fetch(request).first else {
            throw NSError(
                domain: "DocumentRepository",
                code: 9003,
                userInfo: [NSLocalizedDescriptionKey: "Document not found"]
            )
        }

        return document.lockViaFaceId
    }
    
    private func containerType(for document: DocumentEntity) -> DocumentContainerType {
        DocumentContainerType(
            rawValue: document.containerTypeRaw
        ) ?? .regular
    }
    
    private func makeRegularPreviewModels(
        pages: [LoadedDocumentPage],
        fallbackType: DocumentTypeEnum
    ) -> [ScanPreviewModel] {
        guard !pages.isEmpty else { return [] }

        let docType = pages.first?.sourceDocumentType ?? fallbackType

        switch docType {
        case .documents, .passport:
            return pages.map {
                ScanPreviewModel(
                    documentType: $0.sourceDocumentType,
                    frames: [$0.frame]
                )
            }

        case .idCard, .driverLicense:
            return [
                ScanPreviewModel(
                    documentType: docType,
                    frames: pages.map(\.frame)
                )
            ]
        case .qrCode:
            return []
        }
    }
    
    private func makeMergedPreviewModels(
        pages: [LoadedDocumentPage]
    ) -> [ScanPreviewModel] {
        guard !pages.isEmpty else { return [] }

        var result: [ScanPreviewModel] = []
        var index = 0

        while index < pages.count {
            let current = pages[index]

            switch current.sourceDocumentType {
            case .documents, .passport:
                result.append(
                    ScanPreviewModel(
                        documentType: current.sourceDocumentType,
                        frames: [current.frame]
                    )
                )
                index += 1

            case .idCard, .driverLicense:
                var frames: [CapturedFrame] = [current.frame]

                if index + 1 < pages.count,
                   pages[index + 1].sourceDocumentType == current.sourceDocumentType {
                    frames.append(pages[index + 1].frame)
                    index += 2
                } else {
                    index += 1
                }

                result.append(
                    ScanPreviewModel(
                        documentType: current.sourceDocumentType,
                        frames: frames
                    )
                )
            case .qrCode:
                return []
            }
        }

        return result
    }
    
    private func makePreviewPageGroups(
        for document: DocumentEntity
    ) throws -> [PreviewPageGroup] {
        let pages = try loadPages(for: document)
        let containerType = containerType(for: document)
        let fallbackType = DocumentTypeEnum(
            rawValue: document.documentTypeRaw ?? ""
        ) ?? .documents

        switch containerType {
        case .regular:
            return makeRegularPreviewPageGroups(
                pages: pages,
                fallbackType: fallbackType
            )

        case .merged:
            return makeMergedPreviewPageGroups(
                pages: pages
            )
        }
    }
    
    private func makeRegularPreviewPageGroups(
        pages: [LoadedDocumentPage],
        fallbackType: DocumentTypeEnum
    ) -> [PreviewPageGroup] {
        guard !pages.isEmpty else { return [] }

        let docType = pages.first?.sourceDocumentType ?? fallbackType

        switch docType {
        case .documents, .passport:
            return pages.map {
                PreviewPageGroup(
                    documentType: $0.sourceDocumentType,
                    frames: [$0.frame]
                )
            }

        case .idCard, .driverLicense:
            return [
                PreviewPageGroup(
                    documentType: docType,
                    frames: pages.map(\.frame)
                )
            ]
        case .qrCode:
            return []
        }
    }
    
    private func makeMergedPreviewPageGroups(
        pages: [LoadedDocumentPage]
    ) -> [PreviewPageGroup] {
        guard !pages.isEmpty else { return [] }

        var result: [PreviewPageGroup] = []
        var index = 0

        while index < pages.count {
            let current = pages[index]

            switch current.sourceDocumentType {
            case .documents, .passport:
                result.append(
                    PreviewPageGroup(
                        documentType: current.sourceDocumentType,
                        frames: [current.frame]
                    )
                )
                index += 1

            case .idCard, .driverLicense:
                var frames: [CapturedFrame] = [current.frame]

                if index + 1 < pages.count,
                   pages[index + 1].sourceDocumentType == current.sourceDocumentType {
                    frames.append(pages[index + 1].frame)
                    index += 2
                } else {
                    index += 1
                }

                result.append(
                    PreviewPageGroup(
                        documentType: current.sourceDocumentType,
                        frames: frames
                    )
                )
            case .qrCode:
                return []
            }
        }

        return result
    }
}
