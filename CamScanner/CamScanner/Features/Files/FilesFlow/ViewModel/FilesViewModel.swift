import Foundation
import Combine
import UIKit

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var folderToOpen: UUID?
    @Published var viewState: FileViewState = .empty
    @Published var sortType: FilesSortType = .recent
    @Published var viewMode: FilesViewMode = .grid
    @Published private(set) var items: [FilesGridItem] = []
    
    @Published var selectedIDs: Set<UUID> = []
    @Published var isSelectable: Bool = false
    
    @Published var isSearchLoading = false
    @Published var searchText: String = ""
    
    @Published var highlightedID: UUID?
    @Published var shouldShowNotification = false
    @Published var notificationOverlaystate: FilesNotificationOverlayState = .none
    @Published var notificationModel: NotificationModel?
    @Published var fileActiveSheet: FileActiveSheet?
    
    private var pendingAction: FilesPendingAction?
    private var selectableMenuAction: FilesSelectableMenuItem?
    
    private let lockedActionExecutore = LockedActionExecutor.shared
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
            let updatedItems = applyThumbnails(
                to: items,
                thumbs: thumbs
            )
            
            self.items = updatedItems
            self.isSearchLoading = false

            if self.viewState == .search {
                return
            }
            
            if self.sortType == .starred || self.sortType == .locked {
                self.viewState = .success
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
    
    private func applyThumbnails(
        to items: [FilesGridItem],
        thumbs: [ThumbKey: UIImage]
    ) -> [FilesGridItem] {
        items.map { item in
            switch item {
            case .document(var doc):
                doc.thumbnail =
                    thumbs[ThumbKey(docID: doc.id, pageIndex: 0)]

                doc.secondThumbnail =
                    thumbs[ThumbKey(docID: doc.id, pageIndex: 1)]

                return .document(doc)
            case .folder(var folder):
                folder.previewDocuments =
                    folder.previewDocuments.map { preview in
                        var copy = preview

                        copy.thumbnail =
                            thumbs[ThumbKey(docID: preview.id, pageIndex: 0)]

                        copy.secondThumbnail =
                            thumbs[ThumbKey(docID: preview.id, pageIndex: 1)]

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
    
    private func getPasswordData(for id: UUID) -> (salt: Data, hash: Data)? {
        try? documentRepository.getPasswordData(for: id)
    }
    
    func processSuccessMenuItemSelection(id: UUID, menuItem: FilesMenuItem) {
        switch menuItem {
        case .share:
            let documentType = typeForItem(id: id)
            if documentType == .folder,
               let items = try? documentStore.getDocumentItems(inFolder: id),
               !items.isEmpty {
                if items.contains(where: { $0.isLocked }) {
                    let queue = items.map {
                        UnlockQueueItem(id: $0.id, title: $0.title, isLocked: $0.isLocked)
                    }
                    
                    selectableMenuAction = .share
                    notificationOverlaystate = .multipleUnlock(queue)
                } else {
                    fileActiveSheet = .share(id)
                }
            }
            
            if documentType == .document {
                fileActiveSheet = .share(id)
            }
        case .unlockDocument:
            notificationOverlaystate = .unlock(id)
        case .delete:
            notificationOverlaystate = .deleteFile(id)
        default:
            break
        }
    }
    
    private func performLockedAction(
        id: UUID,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping () -> Void
    ) {
        Task {
            let result = await lockedActionExecutore.execute(
                isLocked: isDocumentLocked(id: id),
                isFaceIdEnabled: isDocumentLockViaFaceId(id: id)
            )

            await MainActor.run {
                if result.success {
                    onSuccess()
                } else if result.requiresPin {
                    onFailure()
                    notificationOverlaystate = .unlock(id)
                }

            }
        }
    }
    
    func removeFolderFromSelectdIds(ids: [UUID]) -> [UUID] {
        let folderIDs = Set(
            items.compactMap {
                if case .folder(let folder) = $0 {
                    return folder.id
                }
                return nil
            }
        )
        
        return ids.filter { !folderIDs.contains($0) }
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
    
    func handleDocumentSelected(id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }

        items = items.map { item in
            switch item {
            case .document(var doc):
                if doc.id == id {
                    doc.isSelected.toggle()
                }
                
                return .document(doc)
            case .folder(var folder):
                if folder.id == id {
                    folder.isSelected.toggle()
                }
                
                return .folder(folder)
            }
        }
    }
    
    func handleClearSelection() {
        selectedIDs.removeAll()

        items = items.map {
            switch $0 {
            case .document(var doc):
                doc.isSelected = false
                return .document(doc)
            case .folder(var folder):
                folder.isSelected = false
                return .folder(folder)
            }
        }
    }
    
    func handleSelectAll() {
        let ids: [UUID] = items.compactMap {
            switch $0 {
            case .document(let doc): return doc.id
            case .folder(let folder): return folder.id
            }
        }
        
        selectedIDs = Set(ids)
        
        items = items.map { item in
            switch item {
            case .document(var doc):
                doc.isSelected = true
                return .document(doc)
                
            case .folder(var folder):
                folder.isSelected = true
                return .folder(folder)
            }
        }
    }
    
    func openFolderTapped(id: UUID) {
        performLockedAction(id: id) { [weak self] in
            self?.folderToOpen = id
        } onFailure: { [weak self] in
            self?.pendingAction = .openFolder(id)
        }
    }
    
    func executePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil

        switch action {
        case .openFolder(let id):
            folderToOpen = id
        }
    }
    
    func handleApplyFileDocumentMenuItem(id: UUID?, menuItem: FilesMenuItem?) {
        guard let id, let menuItem else { return }
        
        switch menuItem {
        case .share:
            fileActiveSheet = .share(id)
        case .unlockDocument:
            do {
                try documentRepository.removePassword(id: id)
                showNotification(type: .pinRemoved)
                setHighlitedDocument(id)
            } catch {}
        case .delete:
            do {
                try documentRepository.deleteDocument(id: id)
                showNotification(type: typeForItem(id: id) == .document ? .fileRemoved : .folderRemoved)
            } catch {}
        default:
            return
        }
    }
    
    func handleMultipleUnlockAction(ids: [UUID]) {
        let updatedIds = removeFolderFromSelectdIds(ids: ids)
        
        switch selectableMenuAction {
        case .share:
            fileActiveSheet = .multipleShare(updatedIds)
        case .move:
            fileActiveSheet = .move(
                MoveDocumentInputModel(viewMode: viewMode, folderId: nil, documentIDs: updatedIds)
            )
        case .delete:
            notificationOverlaystate = .multipleDelete(ids)
        case .merge:
            if let documents = try? documentStore.fetchDocumentItems(for: updatedIds) {
                fileActiveSheet = .merge(MergeDocumentsInputModel(items: documents))
            }
        default:
            break
        }
    }
    
    func handleSelectableMenuItem(menuItem: FilesSelectableMenuItem?) {
        guard let menuItem else { return }
        selectableMenuAction = menuItem
        
        do {
            let items = try documentStore.fetchUnlockQueueItems(for: selectedIDs)
            
            if items.contains(where: { $0.isLocked }) {
                notificationOverlaystate = .multipleUnlock(items)
            } else {
                handleMultipleUnlockAction(ids: items.map { $0.id })
            }
        } catch {}
    }
    
    func handleFileDocumentMenuItemSelected(id: UUID?, menuItem: FilesMenuItem) {
        guard let id else { return }
        
        performLockedAction(id: id) { [weak self] in
            self?.processSuccessMenuItemSelection(id: id, menuItem: menuItem)
        } onFailure: {}
    }
    
    func handleMoveDocument(id: UUID?) {
        guard let id else { return }
        
        fileActiveSheet = .move(
            MoveDocumentInputModel(
                viewMode: viewMode,
                folderId: nil,
                documentIDs: [id])
        )
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
    
    func handleDocumentMoved(documentIds: [UUID], folderId: UUID?) {
        do {
            try documentRepository.moveDocumentsToFolder(ids: documentIds, toFolder: folderId)
            fileActiveSheet = nil
            showNotification(type: .multipleMoved(documentIds.isEmpty ? 1 : documentIds.count))
            handleClearSelection()
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
    
    func handleMultipleDelete(documensIds: [UUID]) {
        do {
            try documentRepository.deleteItems(ids: documensIds)
            
            isSelectable = false
            selectableMenuAction = nil
            handleClearSelection()
        } catch {
            print(error)
        }
    }
    
    func getTitleForItem(id: UUID?) -> String {
        guard let id, let item = items.first(where: { $0.id == id }) else { return "" }
        return item.title
    }
    
    func getFolderItem(id: UUID?) -> FileFolderItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }?.folder
    }
    
    func makeShareModel(id: UUID?) -> ShareInputModel? {
        guard let id else { return nil }
        return try? documentRepository.loadShareModel(id: id)
    }
    
    func makeShareModel(ids: [UUID]) -> ShareInputModel? {
        try? documentRepository.loadShareModel(ids: ids)
    }
    
    func typeForItem(id: UUID?) -> FilesItemType? {
        items.first { $0.id == id }?.itemType
    }
    
    func isDocumentLocked(id: UUID?) -> Bool {
        guard let id else { return false }
        return items.first { $0.id == id }?.isLocked ?? false
    }
    
    private func isDocumentLockViaFaceId(id: UUID) -> Bool {
        items.first { $0.id == id }?.isFaceIDEnabled ?? false
    }
    
    func showNotification(type: NotificationModel) {
        notificationModel = type
        shouldShowNotification = true
    }
}
