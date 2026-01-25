import Foundation
import CoreData
import UIKit
import Combine

final class HomeViewModel: ObservableObject {
    @Published private(set) var recentModel: [RecentDocumentModel] = []
    @Published private(set) var exploreToolModel: [ExploreToolModel] = []

    private let documentsStore: DocumentsStore = DocumentsStore()

    private var cancellables = Set<AnyCancellable>()
    
    init() {
        subscribeToRecentDocuments()
        bootstap()
    }
    
    private func subscribeToRecentDocuments() {
        documentsStore.documentEntitiesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documentEntities in
                self?.buildRecentDocumentsLayout(documentEntities)
            }
            .store(in: &cancellables)
        
        documentsStore.thumbnailsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thumbs in
                guard let self else { return }

                self.recentModel = self.recentModel.map { item in
                    var copy = item
                    copy.thumbnail = thumbs[ThumbKey(docID: item.id, pageIndex: 0)]
                    copy.secondThumbnail = thumbs[ThumbKey(docID: item.id, pageIndex: 1)]
                    return copy
                }
            }
            .store(in: &cancellables)
    }
    
    private func bootstap() {
        buildLayoutExplore()
    }
    
    private func buildRecentDocumentsLayout(_ documents: [DocumentEntity]) {
        let mappedDocuments: [RecentDocumentModel] = documents.compactMap { document in
            guard let id = document.id else { return nil }

            let pages = (document.pages as? Set<PageEntity>) ?? []
            let sorted = pages.sorted { $0.index < $1.index }

            let p0 = sorted.indices.contains(0) ? sorted[0].imagePath : nil
            let p1 = sorted.indices.contains(1) ? sorted[1].imagePath : nil

            documentsStore.loadThumbnailsIfNeeded(docID: id, pagePaths: [p0, p1])

            let kind = RecentDocumentModel.Kind(document.kind ?? "")
            let pageCount = Int(document.pageCount) > 1 ? "\(Int(document.pageCount)) pages" : "1 page"

            return RecentDocumentModel(
                id: id,
                title: kind.title,
                kind: kind,
                idType: document.idType,
                thumbnail: nil,
                secondThumbnail: nil,
                firstPageImagePath: p0,
                secondPageImagePath: p1,
                pageCount: pageCount,
                isLocked: document.isLocked,
                createdAt: document.createdAt ?? Date(),
                rememberedFilter: document.rememberedFilter
            )
        }

        recentModel = mappedDocuments
    }
    
    private func buildLayoutExplore() {
        exploreToolModel = [
            ExploreToolModel(type: .recognize, icon: .recognizeImage, title: "Recognize text"),
            ExploreToolModel(type: .addText, icon: .addTextImage, title: "Add text"),
            ExploreToolModel(type: .erase, icon: .eraseImage, title: "Erase"),
            ExploreToolModel(type: .translate, icon: .translateImage, title: "Translate text"),
            ExploreToolModel(type: .signature, icon: .signatureImage, title: "Signature"),
            ExploreToolModel(type: .watermart, icon: .watermarkImage, title: "Watermark"),
            ExploreToolModel(type: .cloudStorage, icon: .cloudImage, title: "Cloud Storage")
        ]
    }
}

extension HomeViewModel {
    func delete(docID: UUID) {
        do {
            try documentsStore.delete(docID: docID)
        } catch {
            print("Delete error:", error)
        }
    }
}
