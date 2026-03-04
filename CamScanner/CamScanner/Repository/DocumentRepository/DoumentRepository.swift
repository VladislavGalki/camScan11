import Foundation
import CoreData
import UIKit

final class DocumentRepository {
    static let shared = DocumentRepository(
        context: PersistenceController.shared.container.viewContext
    )
    
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - LOAD
    
    func loadDocument(id: UUID) throws -> [CapturedFrame] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        guard let document = try context.fetch(request).first else {
            return []
        }
        
        let pages = (document.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []
        
        return pages.compactMap { page in
            guard
                let originalPath = page.originalPath,
                let originalImage = UIImage(
                    contentsOfFile: FileStore.shared.url(forRelativePath: originalPath).path
                )
            else { return nil }
            
            var frame = CapturedFrame()
            
            frame.original = originalImage
            frame.previewBase = originalImage
            frame.displayBase = originalImage
            
            if let quadData = page.quadData {
                frame.quad = QuadCodec.decode(quadData)
            }
            
            frame.drawingData = page.drawingData
            
            if let drawingPath = page.drawingBasePath,
               let drawingImage = UIImage(
                contentsOfFile: FileStore.shared.url(forRelativePath: drawingPath).path
               ) {
                frame.drawingBase = drawingImage
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
            
            frame.preview = FilterRenderer.shared.render(
                image: originalImage,
                state: state
            )
            
            return frame
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
        doc.title = configureDocumentFileName(createAt: doc.createdAt, documentType: doc.documentTypeRaw)
        
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
