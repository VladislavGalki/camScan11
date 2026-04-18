import Foundation
import CoreData
import UIKit

final class DocumentRepositoryOLD {

    static let shared = DocumentRepositoryOLD(
        context: PersistenceController.shared.container.viewContext
    )

    internal let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    enum DocKind: String { case scan, id }

    struct PageInput {
        let displayImage: UIImage
        let originalFullImage: UIImage
        let quad: Quadrilateral?
        let drawingData: Data?
        let drawingBaseImage: UIImage?
        let filterRaw: String?
    }

    func saveDocument(
        kind: DocKind,
        idTypeRaw: String? = nil,
        rememberedFilterRaw: String? = nil,
        pages: [PageInput]
    ) throws -> UUID {

        let docID = UUID()

        let doc = DocumentEntity(context: context)
        doc.id = docID
        doc.createdAt = Date()
        doc.pageCount = Int16(pages.count)

        for (idx, p) in pages.enumerated() {
            let pageID = UUID()

            let displayURL = try FileStore.shared.saveJPEG(
                image: p.displayImage,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_display.jpg"
            )

            let originalURL = try FileStore.shared.saveJPEG(
                image: p.originalFullImage,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_full.jpg"
            )

            let page = PageEntity(context: context)
            page.id = pageID
            page.index = Int16(idx)

            page.imagePath = FileStore.shared.relativePath(fromAbsolute: displayURL)

            page.originalPath = FileStore.shared.relativePath(fromAbsolute: originalURL)

            page.quadData = p.quad.flatMap { QuadCodec.encode($0) }

            if let baseImg = p.drawingBaseImage {
                let baseURL = try FileStore.shared.saveJPEG(
                    image: baseImg,
                    docID: docID,
                    pageID: pageID,
                    fileName: "\(pageID.uuidString)_drawingBase.jpg"
                )
                page.drawingBasePath = FileStore.shared.relativePath(fromAbsolute: baseURL)
            } else {
                page.drawingBasePath = nil
            }

            page.drawingData = p.drawingData

            page.document = doc
        }

        try context.save()
        return docID
    }
    
    // MARK: - Update existing doc (replace pages)

    func updateDocument(
        docID: UUID,
        kind: DocKind,
        idTypeRaw: String? = nil,
        rememberedFilterRaw: String? = nil,
        pages: [PageInput]
    ) throws {

        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", docID as CVarArg)
        req.fetchLimit = 1

        guard let doc = try context.fetch(req).first else {
            throw NSError(domain: "Doc", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found"])
        }

        FileStore.shared.deleteDocumentFolder(docID: docID)

        if let oldPages = doc.pages as? Set<PageEntity> {
            for p in oldPages {
                context.delete(p)
            }
        }

        doc.pageCount = Int16(pages.count)
        doc.createdAt = doc.createdAt ?? Date()

        for (idx, p) in pages.enumerated() {
            let pageID = UUID()

            let displayURL = try FileStore.shared.saveJPEG(
                image: p.displayImage,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_display.jpg"
            )

            let originalURL = try FileStore.shared.saveJPEG(
                image: p.originalFullImage,
                docID: docID,
                pageID: pageID,
                fileName: "\(pageID.uuidString)_full.jpg"
            )

            let page = PageEntity(context: context)
            page.id = pageID
            page.index = Int16(idx)

            page.imagePath = FileStore.shared.relativePath(fromAbsolute: displayURL)
            page.originalPath = FileStore.shared.relativePath(fromAbsolute: originalURL)

            page.quadData = p.quad.flatMap { QuadCodec.encode($0) }
            
            if let baseImg = p.drawingBaseImage {
                let baseURL = try FileStore.shared.saveJPEG(
                    image: baseImg,
                    docID: docID,
                    pageID: pageID,
                    fileName: "\(pageID.uuidString)_drawingBase.jpg"
                )
                page.drawingBasePath = FileStore.shared.relativePath(fromAbsolute: baseURL)
            } else {
                page.drawingBasePath = nil
            }
            
            page.drawingData = p.drawingData

            page.document = doc
        }

        try context.save()
    }

    // MARK: - Fetch

    func fetchDocuments(limit: Int = 50) throws -> [DocumentEntity] {
        let req = DocumentEntity.fetchRequest()
        req.fetchLimit = limit
        req.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        return try context.fetch(req)
    }

    func fetchPages(for document: DocumentEntity) -> [PageEntity] {
        let set = document.pages as? Set<PageEntity> ?? []
        return set.sorted { $0.index < $1.index }
    }

    // MARK: - Delete

    func delete(_ doc: DocumentEntity) throws {
        if let id = doc.id {
            FileStore.shared.deleteDocumentFolder(docID: id)
        }
        context.delete(doc)
        try context.save()
    }
}
