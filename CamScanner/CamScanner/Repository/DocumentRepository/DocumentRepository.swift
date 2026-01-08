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

    enum DocKind: String { case scan, id }

    struct PageInput {
        /// То, что реально сохраняем на диск (у нас “без фильтра” JPEG)
        let image: UIImage
        /// Quad в координатах ORIGINAL (full image) — если есть
        let quad: Quadrilateral?
        /// Фильтр, применённый на превью/последний выбранный (если хочешь per-page)
        let filterRaw: String?
    }

    /// Сохраняем документ в CoreData + файлы в Application Support через FileStore.
    /// - Returns: UUID документа
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
        doc.kind = kind.rawValue
        doc.idType = idTypeRaw
        doc.rememberedFilter = rememberedFilterRaw
        doc.pageCount = Int16(pages.count)

        for (idx, p) in pages.enumerated() {
            let pageID = UUID()
            let url = try FileStore.shared.saveJPEG(image: p.image, docID: docID, pageID: pageID)

            let page = PageEntity(context: context)
            page.id = pageID
            page.index = Int16(idx)
            page.imagePath = url.path
            page.quadData = p.quad.flatMap { QuadCodec.encode($0) }
            page.filter = p.filterRaw
            page.document = doc
        }

        try context.save()
        return docID
    }

    // MARK: - Fetch (на будущее)

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

    // MARK: - Delete (на будущее)

    func delete(_ doc: DocumentEntity) throws {
        if let id = doc.id {
            FileStore.shared.deleteDocumentFolder(docID: id)
        }
        context.delete(doc)
        try context.save()
    }
}
