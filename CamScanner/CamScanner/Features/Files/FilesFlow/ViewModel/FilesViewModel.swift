import Foundation
import Combine
import UIKit

final class FilesViewModel: ObservableObject {
    @Published private(set) var viewState: FileViewState = .empty
    @Published private(set) var gridLayout: FileGridLayout = .grid
    @Published private(set) var items: [FilesGridItem] = []
    
    private let documentStore = FileDocumentStore()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        subscribeFileDocuments()
    }
    
    private func subscribeFileDocuments() {
        documentStore.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.items = items
                
                if !items.isEmpty {
                    self?.viewState = .success
                }
            }
            .store(in: &cancellables)
        
        documentStore.thumbnailsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thumbs in
                self?.applyThumbnails(thumbs)
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
