import Foundation
import Combine

final class FolderViewModel: ObservableObject {
    @Published var highlightedID: UUID?

    @Published private(set) var viewState: FolderViewState = .empty
    @Published private(set) var folderTitle: String = ""
    @Published private(set) var items: [FilesGridItem] = []
    
    @Published var notificationOverlaystate: FilesNotificationOverlayState = .none
    @Published var folderActiveSheet: FolderActiveSheet?
    
    @Published var shouldShowNotification = false
    @Published var notificationModel: NotificationModel?
    
    let viewMode: FilesViewMode
    var folderItem: FileFolderItem
    
    private let documentStore: FolderDocumentStore
    private let documentRepository = DocumentRepository.shared
    private let passwordCryptoService = PasswordCryptoService.shared
    private let faceIdService = FaceIDService.shared
    
    private let onFolderDeleted: () -> Void

    private var cancellables = Set<AnyCancellable>()
    
    init(inputModel: FolderInputModel, onFolderDeleted: @escaping () -> Void) {
        self.documentStore = FolderDocumentStore(folderID: inputModel.folderItem.id)
        self.folderItem = inputModel.folderItem
        self.folderTitle = inputModel.folderItem.title
        self.viewMode = inputModel.viewMode
        self.onFolderDeleted = onFolderDeleted
        
        subscribeFolderDocuments()
    }
    
    private func subscribeFolderDocuments() {
        Publishers.CombineLatest(
            documentStore.itemsPublisher,
            documentStore.thumbnailsPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] items, thumbs in
            guard let self else { return }

            var updated = items
            
            updated = updated.map { item in
                switch item {
                case .document(var doc):
                    doc.thumbnail = thumbs[
                        ThumbKey(docID: doc.id, pageIndex: 0)
                    ]
                    
                    doc.secondThumbnail = thumbs[
                        ThumbKey(docID: doc.id, pageIndex: 1)
                    ]

                    return .document(doc)
                case .folder:
                    return item
                }
            }

            self.items = updated
            self.viewState = updated.isEmpty ? .empty : .success
        }
        .store(in: &cancellables)
    }
    
    func getTitleForItem(id: UUID?) -> String {
        if id == folderItem.id {
            return folderTitle
        }
        
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
    
    private func getPasswordData(for id: UUID) -> (salt: Data, hash: Data)? {
        if id == folderItem.id,
           let salt = folderItem.passwordSalt,
           let hash = folderItem.passwordHash {
            return (salt, hash)
        }
        
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
    
    private func isDocumentLockViaFaceId(id: UUID) -> Bool {
        items.contains {
            switch $0 {
            case .document(let doc): return doc.id == id && doc.lockViaFaceId
            case .folder(let folder): return folder.id == id && folder.lockViaFaceId
            }
        }
    }
    
    private func processSuccessMenuItemSelection(id: UUID, menuItem: FilesMenuItem) {
        switch menuItem {
        case .share:
            folderActiveSheet = .share(id)
        case .unlockDocument:
            notificationOverlaystate = .unlock(id)
        case .delete:
            notificationOverlaystate = .deleteFile(id)
        default:
            break
        }
    }
    
    private func setHighlitedDocument(_ id: UUID) {
        highlightedID = id
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            highlightedID = nil
        }
    }
    
    private func showNotification(type: NotificationModel) {
        notificationModel = type
        shouldShowNotification = true
    }
}

// MARK: - Public
extension FolderViewModel {
    func handleMoveDocument(id: UUID?) {
        guard let id else { return }
        
        folderActiveSheet = .move(
            MoveDocumentInputModel(
                viewMode: viewMode,
                folderId: folderItem.id,
                documentIDs: [id])
        )
    }
    
    func handleDocumentMoved(documentIds: [UUID], folderId: UUID?) {
        do {
            try documentRepository.moveDocumentsToFolder(ids: documentIds, toFolder: folderId)
            folderActiveSheet = nil
        } catch {}
    }
    
    func handleDocumentFavourite(documentId: UUID, isFavourite: Bool) {
        do {
            try documentRepository.setDocumentFavourite(id: documentId, isFavourite: isFavourite)
        } catch {}
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
    
    func handleFaceIdRequest() async -> Bool {
        await faceIdService.requestAuthorizationIfNeeded()
    }
    
    func handleFileDocumentRenamed(_ id: UUID?, fileName: String) {
        let currentId = id ?? folderItem.id
        
        do {
            try documentRepository.renameDocument(id: currentId, newTitle: fileName)
            folderTitle = fileName
        } catch {}
    }
    
    func handleApplyFileDocumentMenuItem(id: UUID?, menuItem: FilesMenuItem?) {
        guard let id, let menuItem else { return }
        
        switch menuItem {
        case .share:
            folderActiveSheet = .share(id)
        case .unlockDocument:
            do {
                try documentRepository.removePassword(id: id)
                
                if folderItem.id == id {
                    folderItem.isLocked = false
                }
                
                showNotification(type: .pinRemoved)
                setHighlitedDocument(id)
            } catch {}
        case .delete:
            do {
                try documentRepository.deleteDocument(id: id)
                
                if id == folderItem.id {
                    onFolderDeleted()
                    return
                }
                
                showNotification(type: .fileRemoved)
            } catch {}
        default:
            return
        }
    }
    
    func hadleDocumentPinCreated(documentId: UUID?, pin: String, viaFaceId: Bool) {
        guard let documentId else { return }
        do {
            let id = try documentRepository.setPassword(id: documentId, pin: pin, viaFaceId: viaFaceId)
            
            if folderItem.id == id {
                folderItem.isLocked = true
            }
            
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
    
    func handleFileDocumentMenuItemSelected(
        id: UUID?,
        menuItem: FilesMenuItem,
        type: FolderDocumentSelectionType
    ) {
        guard let id = type == .documents ? id : folderItem.id else { return }
        
        let isDocumentLockedViaFaceId = type == .documents ? isDocumentLockViaFaceId(id: id) : folderItem.lockViaFaceId
        let isDocumentLocked = type == .documents ? isDocumentLocked(id: id) : folderItem.isLocked
        
        if isDocumentLocked {
            Task {
                if isDocumentLockedViaFaceId {
                    let authentificated = await faceIdService.authenticateForUnlock()
                    
                    await MainActor.run {
                        if authentificated {
                            processSuccessMenuItemSelection(id: id, menuItem: menuItem)
                        } else {
                            notificationOverlaystate = .unlock(id)
                        }
                    }
                } else {
                    await MainActor.run {
                        notificationOverlaystate = .unlock(id)
                    }
                }
            }
        } else {
            processSuccessMenuItemSelection(id: id, menuItem: menuItem)
        }
    }
    
    func makeShareModel(id: UUID?) -> ShareInputModel? {
        guard let id else { return nil }
        return try? documentRepository.loadShareModel(id: id)
    }
}
