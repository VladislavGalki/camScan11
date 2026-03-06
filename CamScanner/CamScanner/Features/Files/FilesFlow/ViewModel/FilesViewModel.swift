import Foundation
import Combine
import UIKit

final class FilesViewModel: ObservableObject {
    @Published var viewState: FileViewState = .empty
    @Published var sortType: FilesSortType = .recent
    @Published var viewMode: FilesViewMode = .grid
    @Published private(set) var items: [FilesGridItem] = []
    
    @Published var isSearchLoading = false
    @Published var searchText: String = ""
    
    @Published var highlightedID: UUID?
    @Published var shouldShowNotification = false
    @Published var notificationOverlaystate: FilesNotificationOverlayState = .none
    @Published var notificationModel: NotificationModel?
    @Published var fileActiveSheet: FileActiveSheet?
    
    private let passwordCryptoService = PasswordCryptoService.shared
    private let documentRepository: DocumentRepository
    private let documentStore = FileDocumentStore()
    private let faceIdService = FaceIDService.shared
    
    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.documentRepository = DocumentRepository.shared
        bootstrap()
    }
    
    private func bootstrap() {
        subscribeFileDocuments()
        subscribeSearch()
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
            self.isSearchLoading = false

            if self.viewState == .search {
                return
            }

            self.viewState = !updatedItems.isEmpty ? .success : .empty
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
                self?.documentStore.search(text)
            }
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
    
    private func setHighlitedDocument(_ id: UUID) {
        highlightedID = id
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            highlightedID = nil
        }
    }
    
    private func isDocumentLockViaFaceId(id: UUID) -> Bool {
        items.contains {
            switch $0 {
            case .document(let doc): return doc.id == id && doc.lockViaFaceId
            case .folder(let folder): return folder.id == id && folder.lockViaFaceId
            }
        }
    }
    
    func typeForItem(id: UUID) -> FilesItemType? {
        items.first(where: { $0.id == id }).map {
            switch $0 {
            case .document: return .document
            case .folder: return .folder
            }
        }
    }
    
    private func getPasswordData(for id: UUID) -> (salt: Data, hash: Data)? {
        for item in items {
            switch item {
                
            case .document(let doc):
                if doc.id == id,
                   let salt = doc.passwordSalt,
                   let hash = doc.passwordHash {
                    return (salt, hash)
                }
                
            case .folder(let folder):
                if folder.id == id,
                   let salt = folder.passwordSalt,
                   let hash = folder.passwordHash {
                    return (salt, hash)
                }
            }
        }
        
        return nil
    }
    
    private func processSuccessMenuItemSelection(menuItem: FilesMenuItem) {
        switch menuItem {
        case .share:
            break
        case .move:
            break
        case .unlockDocument:
            notificationOverlaystate = .unlock
        case .delete:
            notificationOverlaystate = .deleteFile
        default:
            break
        }
    }
    
    private func showNotification(type: NotificationModel) {
        notificationModel = type
        shouldShowNotification = true
    }
}

// MARK: - Public

extension FilesViewModel {
    func startSearch() {
        items = []
        searchText = ""
        viewState = .search
    }
    
    func clearSearch() {
        viewState = items.isEmpty ? .empty : .success
        documentStore.clearSearch()
    }
    
    func handleFileDocumentMenuItemSelected(id: UUID?, menuItem: FilesMenuItem) {
        guard let id else { return }
        
        let isDocumentLockedViaFaceId = isDocumentLockViaFaceId(id: id)
        
        if isDocumentLocked(id: id) {
            Task {
                if isDocumentLockedViaFaceId {
                    let authentificated = await faceIdService.authenticateForUnlock()
                    
                    await MainActor.run {
                        if authentificated {
                            processSuccessMenuItemSelection(menuItem: menuItem)
                        } else {
                            notificationOverlaystate = .unlock
                        }
                    }
                } else {
                    await MainActor.run {
                        notificationOverlaystate = .unlock
                    }
                }
            }
        } else {
            processSuccessMenuItemSelection(menuItem: menuItem)
        }
    }
    
    func handleApplyFileDocumentMenuItem(id: UUID?, menuItem: FilesMenuItem?) {
        guard let id, let menuItem else { return }
        
        switch menuItem {
        case .share:
            break
        case .unlockDocument:
            do {
                try documentRepository.removePassword(id: id)
                showNotification(type: .pinRemoved)
                setHighlitedDocument(id)
            } catch {}
        case .move:
            break
        case .delete:
            do {
                try documentRepository.deleteDocument(id: id)
                showNotification(type: typeForItem(id: id) == .document ? .fileRemoved : .folderRemoved)
            } catch {}
        default:
            return
        }
    }
    
    func handleFolderCreated(folderName: String) {
        do {
            let documentId = try documentRepository.createFolder(title: folderName)
            showNotification(type: .folderCreated)
            setHighlitedDocument(documentId)
        } catch {}
    }
    
    func handleFilesSortType(type: FilesSortType) {
        sortType = type
        documentStore.updateSortType(type)
    }
    
    func handleFileDocumentRenamed(_ id: UUID?, fileName: String) {
        guard let id else { return }
        
        do {
            try documentRepository.renameDocument(id: id, newTitle: fileName)
        } catch {}
    }
    
    func handleDocumentFavourite(documentId: UUID, isFavourite: Bool) {
        do {
            try documentRepository.setDocumentFavourite(id: documentId, isFavourite: isFavourite)
        } catch {}
    }
    
    func handleFaceIdRequest() async -> Bool {
        await faceIdService.requestAuthorizationIfNeeded()
    }
    
    func hadleDocumentPinCreated(documentId: UUID?, pin: String, viaFaceId: Bool) {
        guard let documentId else { return }
        do {
            let id = try documentRepository.setPassword(id: documentId, pin: pin, viaFaceId: viaFaceId)
            showNotification(type: .pinCreated)
            setHighlitedDocument(id)
        } catch {}
    }
    
    func handleDocumentPinValidation(documentId: UUID?, pin: String) -> Bool {
        guard let documentId, let documentData = getPasswordData(for: documentId) else { return false }
        
        return passwordCryptoService.verify(
            pin: pin,
            salt: documentData.salt,
            hash: documentData.hash
        )
    }
    
    func getTitleForItem(id: UUID?) -> String {
        for item in items {
            switch item {
            case .document(let doc):
                if doc.id == id {
                    return doc.title
                }
            case .folder(let folder):
                if folder.id == id {
                    return folder.title
                }
            }
        }
        
        return ""
    }
    
    func isDocumentLocked(id: UUID?) -> Bool {
        guard let id else { return false }
        
        return items.contains {
            switch $0 {
            case .document(let doc): return doc.id == id && doc.isLocked
            case .folder(let folder): return folder.id == id && folder.isLocked
            }
        }
    }
}
