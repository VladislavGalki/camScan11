import Foundation
import CoreData
import UIKit
import Combine

final class HomeViewModel: ObservableObject {
    @Published private(set) var recentModel: [RecentDocumentModel] = []
    @Published private(set) var exploreToolModel: [ExploreToolModel] = []
    @Published var searchText: String = ""
    @Published var isSearchLoading = false
    @Published var isSearchActive = false
    @Published private(set) var searchItems: [FilesGridItem] = []
    @Published var documentToOpen: UUID?
    @Published var pinDocumentIDToOpen: UUID?

    private let documentRepository: DocumentRepository = DocumentRepository.shared
    private let documentsStore: HomeDocumentsStore = HomeDocumentsStore()
    private let fileDocumentStore: FileDocumentStore = FileDocumentStore()
    private let passwordCryptoService = PasswordCryptoService.shared
    private let lockedActionExecutor = LockedActionExecutor.shared

    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        subscribeToRecentDocuments()
        subscribeToSearchDocuments()
        subscribeSearch()
        bootstap()
    }
    
    func handleDocumentFavourite(documentId: UUID, isFavourite: Bool) {
        do {
            try documentRepository.setDocumentFavourite(id: documentId, isFavourite: isFavourite)
        } catch {}
    }

    func startSearch() {
        searchItems = []
        searchText = ""
        isSearchActive = true
    }

    func clearSearch() {
        isSearchActive = false
        searchText = ""
        isSearchLoading = false
        fileDocumentStore.clearSearch()
    }

    func openDocumentTapped(id: UUID) {
        Task {
            let result = await lockedActionExecutor.execute(
                isLocked: isDocumentLocked(id: id),
                isFaceIdEnabled: isDocumentLockViaFaceId(id: id)
            )

            await MainActor.run {
                if result.success {
                    documentToOpen = id
                } else if result.requiresPin {
                    pinDocumentIDToOpen = id
                }
            }
        }
    }

    func validateDocumentPin(documentId: UUID, pin: String) -> Bool {
        guard let documentData = try? documentRepository.getPasswordData(for: documentId) else {
            return false
        }

        return passwordCryptoService.verify(
            pin: pin,
            salt: documentData.salt,
            hash: documentData.hash
        )
    }

    func finishLockedDocumentOpen(documentId: UUID) {
        pinDocumentIDToOpen = nil
        documentToOpen = documentId
    }

    func clearPendingPinRequest() {
        pinDocumentIDToOpen = nil
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

    private func subscribeToSearchDocuments() {
        fileDocumentStore.bootstrap(with: .recent)

        Publishers.CombineLatest(
            fileDocumentStore.itemsPublisher,
            fileDocumentStore.thumbnailsPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] items, thumbs in
            guard let self else { return }

            let documentItems = items.compactMap { item -> FilesGridItem? in
                guard case .document(var doc) = item else { return nil }
                doc.thumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 0)]
                doc.secondThumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 1)]
                return .document(doc)
            }

            self.searchItems = documentItems
            self.isSearchLoading = false
        }
        .store(in: &cancellables)
    }

    private func subscribeSearch() {
        searchCancellable = $searchText
            .dropFirst()
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isSearchLoading = true
            })
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.fileDocumentStore.search(text)
            }
    }
    
    private func bootstap() {
        buildLayoutExplore()
    }
    
    private func buildRecentDocumentsLayout(_ documents: [DocumentEntity]) {
        let mappedDocuments: [RecentDocumentModel] = documents.compactMap { document in
            guard
                let id = document.id,
                let rawType = document.documentTypeRaw,
                let docType = DocumentTypeEnum(rawValue: rawType)
            else { return nil }

            let pages = (document.pages as? Set<PageEntity>) ?? []
            let sorted = pages.sorted { $0.index < $1.index }

            let p0 = sorted.indices.contains(0) ? sorted[0].imagePath : nil
            let p1 = sorted.indices.contains(1) ? sorted[1].imagePath : nil

            documentsStore.loadThumbnailsIfNeeded(docID: id, pagePaths: [p0, p1])

            let pageCount = Int(document.pageCount)
            let pageText = pageCount > 1 ? "\(pageCount) pages" : "1 page"

            return RecentDocumentModel(
                id: id,
                title: document.title,
                documentType: docType,
                previewDocumentType: previewDocumentType(for: document),
                isMerged: isMergedDocument(document),
                thumbnail: nil,
                secondThumbnail: nil,
                firstPageImagePath: p0,
                secondPageImagePath: p1,
                pageCountText: pageText,
                isFavorite: document.isFavourite,
                isLocked: document.isLocked,
                lockViaFaceId: document.lockViaFaceId,
                createdAt: document.createdAt,
                lastViewedAt: document.lastViewed
            )
        }
        .sorted { $0.lastViewedAt > $1.lastViewedAt }

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

//MARK: - Helpers
extension HomeViewModel {
    func isDocumentLocked(id: UUID) -> Bool {
        if let recent = recentModel.first(where: { $0.id == id }) {
            return recent.isLocked
        }

        if let item = searchItems.first(where: { $0.id == id })?.document {
            return item.isLocked
        }

        return (try? documentRepository.fetchDocumentIsLocked(id: id)) ?? false
    }

    func isDocumentLockViaFaceId(id: UUID) -> Bool {
        if let recent = recentModel.first(where: { $0.id == id }) {
            return recent.lockViaFaceId
        }

        if let item = searchItems.first(where: { $0.id == id })?.document {
            return item.lockViaFaceId
        }

        return (try? documentRepository.fetchDocumentLockViaFaceId(id: id)) ?? false
    }

    private func previewDocumentType(for document: DocumentEntity) -> DocumentTypeEnum {
        let defaultType = DocumentTypeEnum(
            rawValue: document.documentTypeRaw ?? ""
        ) ?? .documents

        let containerType = DocumentContainerType(
            rawValue: document.containerTypeRaw
        ) ?? .regular

        guard containerType == .merged else {
            return defaultType
        }

        let pages = (document.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        guard let firstPage = pages.first else {
            return defaultType
        }

        return DocumentTypeEnum(
            rawValue: firstPage.sourceDocumentTypeRaw
        ) ?? defaultType
    }

    private func isMergedDocument(_ document: DocumentEntity) -> Bool {
        let containerType = DocumentContainerType(
            rawValue: document.containerTypeRaw
        ) ?? .regular

        return containerType == .merged
    }
}
