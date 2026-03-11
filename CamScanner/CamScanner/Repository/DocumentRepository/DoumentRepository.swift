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
}

// MARK: Documents
extension DocumentRepository {
    @discardableResult
    func saveDocument(
        documentType: DocumentTypeEnum,
        frames: [CapturedFrame],
        folder: FolderEntity? = nil
    ) throws -> UUID {
        let docID = UUID()
        
        let doc = DocumentEntity(context: context)
        doc.id = docID
        
        doc.createdAt = Date()
        doc.lastViewed = Date()
        doc.documentTypeRaw = documentType.rawValue
        doc.pageCount = Int16(frames.count)
        doc.folder = folder
        doc.title = configureDocumentFileName(createAt: doc.createdAt, documentType: documentType.title)
        
        for (index, frame) in frames.enumerated() {
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
        request.predicate = NSPredicate(format: "id IN %@", ids)

        let documents = try context.fetch(request)

        return try buildShareModel(from: documents)
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

        var pages: [ScanPreviewModel] = []

        for document in documents {
            let docType = DocumentTypeEnum(
                rawValue: document.documentTypeRaw ?? ""
            ) ?? .documents

            let frames = try loadFrames(for: document)

            if docType == .documents || docType == .passport {
                frames.forEach {
                    pages.append(
                        ScanPreviewModel(
                            documentType: docType,
                            frames: [$0]
                        )
                    )
                }
            } else {
                pages.append(
                    ScanPreviewModel(
                        documentType: docType,
                        frames: frames
                    )
                )
            }
        }

        let firstType = DocumentTypeEnum(
            rawValue: first.documentTypeRaw ?? ""
        ) ?? .documents

        return ShareInputModel(
            documentName: first.title,
            documentType: firstType,
            pages: pages
        )
    }
    
    private func loadFrames(for document: DocumentEntity) throws -> [CapturedFrame] {
        let pages = (document.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        return pages.compactMap { page in
            guard
                let originalPath = page.imagePath,
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
            frame.previewBase = frame.preview ?? originalImage

            if let base = frame.previewBase {
                frame.previewBase = ImageCompressionService.shared.compress(
                    base,
                    maxDimension: 1200,
                    quality: 0.90
                )
            }

            frame.displayBase = frame.previewBase
            frame.preview = frame.displayBase

            print("previewBase == original", frame.previewBase === frame.original)
            
            return frame
        }
    }
    
    func saveMockDocument(
        documentType: DocumentTypeEnum = .documents,
        pages: Int = 3
    ) throws -> UUID {

        let frames = MockFrameFactory.makeFrames(count: pages)

        return try saveDocument(
            documentType: documentType,
            frames: frames,
            folder: nil
        )
    }
}


enum MockFrameFactory {

    static func makeFrames(count: Int = 3) -> [CapturedFrame] {
        var frames: [CapturedFrame] = []

        for i in 1...count {

            guard
                let image = UIImage(named: "folder_image")
            else { continue }

            let frame = CapturedFrame(
                preview: image,
                previewBase: image,
                displayBase: image,
                original: nil,
                quad: nil,
                drawingData: nil,
                drawingBase: nil,
                filteredBase: nil,
                filterAdjustments: [:]
            )

            frames.append(frame)
        }

        return frames
    }
}
