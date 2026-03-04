import Foundation
import Combine
import UIKit

final class FilesViewModel: ObservableObject {
    @Published private(set) var viewState: FileViewState = .empty
    @Published var sortType: FilesSortType = .recent
    @Published var viewMode: FilesViewMode = .grid
    @Published private(set) var items: [FilesGridItem] = []
    
    @Published var shouldShowNotification = false
    @Published var notificationModel: NotificationModel?
    @Published var fileActiveSheet: FileActiveSheet?
    
    private let documentRepository: DocumentRepository
    private let documentStore = FileDocumentStore()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.documentRepository = DocumentRepository.shared
        bootstrap()
    }
    
    func handleFolderCreated(folderName: String) {
        do {
            try documentRepository.createFolder(title: folderName)
            notificationModel = .folderCreated
            shouldShowNotification = true
        } catch {}
    }
    
    func handleFilesSortType(type: FilesSortType) {
        sortType = type
        documentStore.updateSortType(type)
    }
    
    func handleDocumentFavourite(documentId: UUID, isFavourite: Bool) {
        do {
            try documentRepository.setDocumentFavourite(id: documentId, isFavourite: isFavourite)
        } catch {}
    }
    
    private func bootstrap() {
        subscribeFileDocuments()
        documentStore.bootstrap(with: sortType)
    }
    
    private func subscribeFileDocuments() {
        Publishers.CombineLatest(
            documentStore.itemsPublisher,
            documentStore.thumbnailsPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] items, thumbs in
            guard let self else { return }
            
            var updatedItems = items
            
            updatedItems = updatedItems.map { item in
                switch item {
                case .document(var doc):
                    doc.thumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 0)]
                    doc.secondThumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 1)]
                    return .document(doc)
                    
                case .folder(var folder):
                    folder.previewDocuments = folder.previewDocuments.map { preview in
                        var copy = preview
                        copy.thumbnail = thumbs[ThumbKey(docID: preview.id, pageIndex: 0)]
                        copy.secondThumbnail = thumbs[ThumbKey(docID: preview.id, pageIndex: 1)]
                        return copy
                    }
                    return .folder(folder)
                }
            }
            
            self.items = updatedItems
            
            if !updatedItems.isEmpty {
                self.viewState = .success
            }
        }
        .store(in: &cancellables)
    }
    
    private func applyThumbnails(_ thumbs: [ThumbKey: UIImage]) {
        items = items.map { item in
            switch item {
            case .document(var doc):
                doc.thumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 0)]
                doc.secondThumbnail = thumbs[ThumbKey(docID: doc.id, pageIndex: 1)]
                return .document(doc)
                
            case .folder(var folder):
                folder.previewDocuments = folder.previewDocuments.map { preview in
                    var copy = preview
                    copy.thumbnail = thumbs[ThumbKey(docID: preview.id, pageIndex: 0)]
                    copy.secondThumbnail = thumbs[ThumbKey(docID: preview.id, pageIndex: 1)]
                    return copy
                }
                return .folder(folder)
            }
        }
    }
}
