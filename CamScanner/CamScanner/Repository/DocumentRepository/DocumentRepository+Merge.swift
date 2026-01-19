import Foundation
import CoreData
import UIKit

extension DocumentRepository {
    
    func loadFrames(docID: UUID) throws -> [CapturedFrame] {
        guard let doc = try fetchDocument(id: docID) else { return [] }
        let pages = fetchPages(for: doc)

        return pages.map { p in
            let displayURL = FileStore.shared.url(forRelativePath: p.imagePath ?? "")
            let fullURL    = FileStore.shared.url(forRelativePath: p.originalPath ?? "")

            let display = FileStore.shared.loadImage(at: displayURL)
            let full    = FileStore.shared.loadImage(at: fullURL)
            let quad    = p.quadData.flatMap { QuadCodec.decode($0) }

            // ✅ вот это главное:
            let base: UIImage? = {
                guard let rel = p.drawingBasePath, !rel.isEmpty else { return nil }
                let url = FileStore.shared.url(forRelativePath: rel)
                return FileStore.shared.loadImage(at: url)
            }()

            return CapturedFrame(
                preview: display,
                original: full,
                quad: quad,
                drawingData: p.drawingData,
                drawingBase: base
            )
        }
    }
    
    private func fetchDocument(id: UUID) throws -> DocumentEntity? {
        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }
}
