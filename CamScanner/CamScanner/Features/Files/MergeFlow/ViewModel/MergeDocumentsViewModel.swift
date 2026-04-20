import Foundation
import UIKit

@MainActor
final class MergeDocumentsViewModel: ObservableObject {
    @Published var items: [FileDocumentItem]
    
    private let onMerge: () -> Void
    
    private var thumbnails: [ThumbKey: UIImage] = [:]
    private var thumbInFlight = Set<ThumbKey>()
    
    private let documentsReposotory: DocumentRepository
    private let fileStore: FileStore

    init(
        inputModel: MergeDocumentsInputModel,
        onMerge: @escaping () -> Void,
        dependencies: AppDependencies
    ) {
        self.items = inputModel.items
        self.onMerge = onMerge
        self.documentsReposotory = dependencies.documentRepository
        self.fileStore = dependencies.fileStore

        loadThumbnails()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func handleMergeAction(shouldRemoveOriginal: Bool = false) {
        let orderedIDs = items.map(\.id)
        
        do {
            try documentsReposotory.mergeDocuments(ids: orderedIDs)
            
            if shouldRemoveOriginal {
                try documentsReposotory.deleteItems(ids: orderedIDs)
            }
            
            onMerge()
        } catch {}
    }
    
    private func loadThumbnails() {
        for item in items {
            loadThumbs(for: item)
        }
    }

    private func loadThumbs(for doc: FileDocumentItem) {
        let paths = [doc.firstPagePath, doc.secondPagePath]

        for (idx, path) in paths.prefix(2).enumerated() {
            guard let relPath = path, !relPath.isEmpty else { continue }

            let key = ThumbKey(docID: doc.id, pageIndex: idx)

            if thumbnails[key] != nil { continue }
            if thumbInFlight.contains(key) { continue }

            let url = fileStore.url(forRelativePath: relPath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            thumbInFlight.insert(key)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }

                let image = self.fileStore.loadImage(at: url)
                let thumb = image?.downscaled(maxDimension: 220)

                DispatchQueue.main.async {
                    self.thumbnails[key] = thumb
                    self.thumbInFlight.remove(key)
                    self.applyThumbnails()
                }
            }
        }
    }

    private func applyThumbnails() {
        items = items.map { item in
            var copy = item
            copy.thumbnail = thumbnails[ThumbKey(docID: item.id, pageIndex: 0)]
            copy.secondThumbnail = thumbnails[ThumbKey(docID: item.id, pageIndex: 1)]
            return copy
        }
    }
}
