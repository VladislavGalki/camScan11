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
    
    // MARK: - SAVE
    
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
        doc.documentTypeRaw = documentType.rawValue
        doc.pageCount = Int16(frames.count)
        doc.folder = folder
        
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
    
    // MARK: - DELETE
    
    func deleteDocument(_ document: DocumentEntity) throws {
        if let id = document.id {
            FileStore.shared.deleteDocumentFolder(docID: id)
        }
        context.delete(document)
        try context.save()
    }
    
    // MARK: - FETCH ALL
    
    func fetchDocuments(limit: Int? = nil) throws -> [DocumentEntity] {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()

        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        if let limit = limit {
            request.fetchLimit = limit
        }

        return try context.fetch(request)
    }
}
