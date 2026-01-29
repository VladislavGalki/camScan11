import Foundation
import CoreData
import UIKit

@MainActor
final class DocumentPreviewEntryViewModel: ObservableObject {

    enum State {
        case loading
        case scan(pages: [CapturedFrame], rememberedFilterKey: String?)
        case id(result: IdCaptureResult, rememberedFilterKey: String?)
        case error(String)
    }

    @Published private(set) var state: State = .loading

    private let context: NSManagedObjectContext = PersistenceController.shared.container.viewContext

    func load(documentID: UUID) {
        state = .loading

//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                let doc = try self.fetchDocument(id: documentID)
//
//                let remembered = doc.rememberedFilter
//                let kind = (doc.kind ?? "scan").lowercased()
//
//                let pages = (doc.pages as? Set<PageEntity> ?? [])
//                    .sorted { $0.index < $1.index }
//
//                if pages.isEmpty {
//                    DispatchQueue.main.async {
//                        self.state = .error("У документа нет страниц")
//                    }
//                    return
//                }
//
//                if kind == "id" {
//                    let result = try self.buildIdResult(doc: doc, pages: pages)
//                    DispatchQueue.main.async {
//                        self.state = .id(result: result, rememberedFilterKey: remembered)
//                    }
//                } else {
//                    let frames = try self.buildScanFrames(pages: pages)
//                    DispatchQueue.main.async {
//                        self.state = .scan(pages: frames, rememberedFilterKey: remembered)
//                    }
//                }
//
//            } catch {
//                DispatchQueue.main.async {
//                    self.state = .error("Ошибка загрузки: \(error.localizedDescription)")
//                }
//            }
//        }
    }

    // MARK: - Fetch

    private func fetchDocument(id: UUID) throws -> DocumentEntity {
        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1

        guard let doc = try context.fetch(req).first else {
            throw NSError(domain: "Doc", code: 404, userInfo: [NSLocalizedDescriptionKey: "Документ не найден"])
        }
        return doc
    }

    // MARK: - Build Scan

    private func buildScanFrames(pages: [PageEntity]) throws -> [CapturedFrame] {
        try pages.map { p in
            guard let displayRel = p.imagePath,
                  let fullRel = p.originalPath else {
                throw NSError(domain: "Doc", code: 2, userInfo: [NSLocalizedDescriptionKey: "Нет путей к файлам страницы"])
            }

            let displayURL = FileStore.shared.url(forRelativePath: displayRel)
            let fullURL    = FileStore.shared.url(forRelativePath: fullRel)

            let display = FileStore.shared.loadImage(at: displayURL)
            let full    = FileStore.shared.loadImage(at: fullURL)
            let quad    = p.quadData.flatMap { QuadCodec.decode($0) }

            // ✅ drawing base
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

    // MARK: - Build ID

//    private func buildIdResult(doc: DocumentEntity, pages: [PageEntity]) throws -> IdCaptureResult {
//        let idType = IdDocumentTypeEnum.allCases.first(where: { $0.id == doc.idType }) ?? .general
//
//        var result = IdCaptureResult(idType: idType, front: .init(), back: idType.requiresBackSide ? .init() : nil)
//
//        let frames = try buildScanFrames(pages: pages)
//
//        if let first = frames.first {
//            result.front.preview = first.preview
//            result.front.original = first.original
//            result.front.quad = first.quad
//            result.front.drawingData = first.drawingData
//            result.front.drawingBase = first.drawingBase
//        }
//
//        if idType.requiresBackSide, frames.count > 1 {
//            var back = CapturedFrame()
//            back.preview = frames[1].preview
//            back.original = frames[1].original
//            back.quad = frames[1].quad
//            back.drawingData = frames[1].drawingData
//            back.drawingBase = frames[1].drawingBase
//            result.back = back
//        } else {
//            result.back = nil
//        }
//
//        return result
//    }
}
