import Foundation
import CoreData
import UIKit

// ✅ То, что удобно рендерить в SwiftUI (без CoreData объектов в UI)
struct DocumentListItem: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let kind: String          // "scan" / "id"
    let idType: String?       // для "id"
    let pageCount: Int
    let rememberedFilter: String?

    /// Абсолютный путь (как ты сейчас сохраняешь: url.path)
    let firstPageImagePath: String?
}

@MainActor
final class DocumentsStore: NSObject, ObservableObject {

    @Published private(set) var items: [DocumentListItem] = []
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]  // docID -> thumb

    private let context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    private var frc: NSFetchedResultsController<DocumentEntity>!

    private var thumbInFlight = Set<UUID>()
    
    override init() {
        super.init()
        setupFRC()
        performFetch()
    }

    // MARK: - Public

    func refresh() {
        performFetch()
    }

    func delete(docID: UUID) throws {
        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", docID as CVarArg)
        req.fetchLimit = 1

        if let doc = try context.fetch(req).first {
            // 1) удалить файлы
            FileStore.shared.deleteDocumentFolder(docID: docID)
            // 2) удалить CoreData
            context.delete(doc)
            try context.save()

            thumbnails[docID] = nil
            thumbInFlight.remove(docID)
        }
    }

    // MARK: - FRC

    private func setupFRC() {
        let request: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        frc.delegate = self
    }

    private func performFetch() {
        do {
            try frc.performFetch()
            rebuildItemsFromFRC()
        } catch {
            print("❌ DocumentsStore fetch error:", error)
            items = []
        }
    }

    private func rebuildItemsFromFRC() {
        let docs = frc.fetchedObjects ?? []

        let mapped: [DocumentListItem] = docs.compactMap { doc in
            guard let id = doc.id else { return nil }

            let pages = (doc.pages as? Set<PageEntity>) ?? []
            let first = pages.sorted { $0.index < $1.index }.first
            let firstPath = first?.imagePath

            return DocumentListItem(
                id: id,
                createdAt: doc.createdAt ?? Date(),
                kind: (doc.kind ?? "scan"),
                idType: doc.idType,
                pageCount: Int(doc.pageCount),
                rememberedFilter: doc.rememberedFilter,
                firstPageImagePath: firstPath
            )
        }

        items = mapped

        // Прогреть миниатюры
        for it in mapped {
            loadThumbnailIfNeeded(for: it)
        }

        // Подчистить кэш миниатюр от удалённых
        let validIDs = Set(mapped.map { $0.id })
        thumbnails.keys.filter { !validIDs.contains($0) }.forEach { thumbnails[$0] = nil }
    }

    private func loadThumbnailIfNeeded(for item: DocumentListItem) {
        guard thumbnails[item.id] == nil else { return }
        guard !thumbInFlight.contains(item.id) else { return }
        guard let relPath = item.firstPageImagePath, !relPath.isEmpty else { return }

        thumbInFlight.insert(item.id)

        let url = FileStore.shared.url(forRelativePath: relPath)
        let exists = FileManager.default.fileExists(atPath: url.path)

        print("thumb rel:", relPath)
        print("thumb abs:", url.path)
        print("thumb exists:", exists)

        // ✅ если файла нет — не держим вечный лоадер
        guard exists else {
            DispatchQueue.main.async { [weak self] in
                self?.thumbInFlight.remove(item.id)
                self?.thumbnails[item.id] = nil // можно оставить nil, но лучше показывать placeholder в UI
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let img = FileStore.shared.loadImage(at: url)
            let thumb = img?.downscaled(maxDimension: 240)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.thumbnails[item.id] = thumb
                self.thumbInFlight.remove(item.id)
            }
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension DocumentsStore: @preconcurrency NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        rebuildItemsFromFRC()
    }
}
