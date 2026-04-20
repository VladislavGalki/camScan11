import SwiftUI

@MainActor
final class OpenDocumentSelectPagesMoveViewModel: ObservableObject {
    @Published var items: [FilesGridItem] = []
    @Published var currentFolderID: UUID?
    @Published var selectedTargetDocumentID: UUID?
    @Published var pendingLockedDocumentID: UUID?

    let viewMode: FilesViewMode = .list
    let inputModel: OpenDocumentSelectPagesMoveInputModel

    private var stack: [UUID] = []
    private var thumbInFlight = Set<ThumbKey>()
    private var thumbnails: [ThumbKey: UIImage] = [:]

    private let documentRepository: DocumentRepository
    private let passwordCryptoService: PasswordCryptoService
    private let lockedActionExecutor: LockedActionExecutor
    private let fileStore: FileStore

    init(inputModel: OpenDocumentSelectPagesMoveInputModel, dependencies: AppDependencies) {
        self.inputModel = inputModel
        self.documentRepository = dependencies.documentRepository
        self.passwordCryptoService = dependencies.passwordCryptoService
        self.lockedActionExecutor = dependencies.lockedActionExecutor
        self.fileStore = dependencies.fileStore
        loadRootItems()
    }

    var title: String {
        "Files"
    }

    var canConfirmMove: Bool {
        selectedTargetDocumentID != nil
    }

    var pendingLockedDocumentTitle: String {
        document(for: pendingLockedDocumentID)?.title ?? ""
    }

    func openFolderTapped(_ id: UUID) {
        thumbnails.removeAll()
        thumbInFlight.removeAll()

        stack.append(id)
        currentFolderID = id
        selectedTargetDocumentID = nil

        let docs = documentRepository.fetchDocuments(in: id)
            .filter { $0.id != inputModel.sourceDocumentID }

        items = docs.map { .document(mapDocument($0)) }
        loadThumbnails()
    }

    func goBackTapped() {
        guard !stack.isEmpty else { return }

        stack.removeLast()
        selectedTargetDocumentID = nil

        if let id = stack.last {
            openFolderTapped(id)
        } else {
            currentFolderID = nil
            loadRootItems()
        }
    }

    func handleDocumentTap(_ id: UUID) async -> OpenDocumentSelectPagesMoveAuthorizationResult {
        if selectedTargetDocumentID == id {
            selectedTargetDocumentID = nil
            return .authorized
        }

        guard let document = document(for: id) else {
            return .failed
        }

        let result = await lockedActionExecutor.execute(
            isLocked: document.isLocked,
            isFaceIdEnabled: document.lockViaFaceId
        )

        if result.success {
            selectedTargetDocumentID = id
            pendingLockedDocumentID = nil
            return .authorized
        }

        if result.requiresPin {
            pendingLockedDocumentID = id
            return .requiresPin
        }

        return .failed
    }

    func handleFolderCreated(folderName: String) {
        do {
            try documentRepository.createFolder(title: folderName)
            loadRootItems()
        } catch {}
    }

    func validatePendingDocumentPin(_ pin: String) -> Bool {
        guard let pendingLockedDocumentID,
              let passwordData = try? documentRepository.getPasswordData(for: pendingLockedDocumentID)
        else { return false }

        return passwordCryptoService.verify(
            pin: pin,
            salt: passwordData.salt,
            hash: passwordData.hash
        )
    }

    func completePendingPinAuthorization() {
        guard let pendingLockedDocumentID else { return }
        selectedTargetDocumentID = pendingLockedDocumentID
        self.pendingLockedDocumentID = nil
    }

    func cancelPendingPinAuthorization() {
        pendingLockedDocumentID = nil
    }

    func moveSelectedPages() -> OpenDocumentSelectPagesMoveResult {
        guard let targetDocumentID = selectedTargetDocumentID else {
            return .failed
        }

        do {
            let sourcePreview = try documentRepository.loadPreviewInputModel(id: inputModel.sourceDocumentID)

            let flattenedPages: [DocumentPagePayload] = sourcePreview.pageGroups.flatMap { group in
                group.frames.map { frame in
                    DocumentPagePayload(frame: frame, sourceDocumentType: group.documentType)
                }
            }

            let safeIndices = Set(inputModel.selectedRawPageIndices)
                .filter { flattenedPages.indices.contains($0) }
                .sorted()

            guard !safeIndices.isEmpty else {
                return .failed
            }

            let pagesToMove = safeIndices.map { flattenedPages[$0] }

            try documentRepository.addPagesToDocument(
                documentID: targetDocumentID,
                pages: pagesToMove
            )

            if safeIndices.count == flattenedPages.count {
                try documentRepository.deleteDocument(id: inputModel.sourceDocumentID)

                NotificationCenter.default.post(
                    name: .openDocumentPreviewDidChange,
                    object: nil,
                    userInfo: ["documentID": inputModel.sourceDocumentID]
                )

                NotificationCenter.default.post(
                    name: .openDocumentPreviewDidChange,
                    object: nil,
                    userInfo: ["documentID": targetDocumentID]
                )

                return .movedAndClosedSource(inputModel.selectedItemsCount)
            }

            for index in safeIndices.sorted(by: >) {
                try documentRepository.deletePage(documentID: inputModel.sourceDocumentID, at: index)
            }

            NotificationCenter.default.post(
                name: .openDocumentPreviewDidChange,
                object: nil,
                userInfo: ["documentID": inputModel.sourceDocumentID]
            )

            NotificationCenter.default.post(
                name: .openDocumentPreviewDidChange,
                object: nil,
                userInfo: ["documentID": targetDocumentID]
            )

            return .moved(inputModel.selectedItemsCount)
        } catch {
            return .failed
        }
    }
}

enum OpenDocumentSelectPagesMoveAuthorizationResult {
    case authorized
    case requiresPin
    case failed
}

private extension OpenDocumentSelectPagesMoveViewModel {
    func document(for id: UUID?) -> FileDocumentItem? {
        guard let id else { return nil }

        for item in items {
            if case let .document(document) = item, document.id == id {
                return document
            }
        }

        return nil
    }

    var selectedTargetDocument: FileDocumentItem? {
        document(for: selectedTargetDocumentID)
    }

    func loadRootItems() {
        thumbnails.removeAll()
        thumbInFlight.removeAll()
        currentFolderID = nil
        stack.removeAll()
        selectedTargetDocumentID = nil

        let folders = documentRepository.fetchFolders()
        let rootDocuments = documentRepository.fetchDocumentsInRoot()
            .filter { $0.id != inputModel.sourceDocumentID }

        items = folders.map { .folder(mapFolder($0)) }
            + rootDocuments.map { .document(mapDocument($0)) }

        loadThumbnails()
    }

    func loadThumbnails() {
        for item in items {
            switch item {
            case .document(let doc):
                loadThumbs(for: doc)
            case .folder(let folder):
                for doc in folder.previewDocuments {
                    loadThumbs(for: doc)
                }
            }
        }
    }

    func loadThumbs(for doc: FileDocumentItem) {
        let paths = [doc.firstPagePath, doc.secondPagePath]

        for (idx, path) in paths.prefix(2).enumerated() {
            guard let relPath = path else { continue }

            let key = ThumbKey(docID: doc.id, pageIndex: idx)
            if thumbnails[key] != nil { continue }
            if thumbInFlight.contains(key) { continue }

            thumbInFlight.insert(key)
            let url = fileStore.url(forRelativePath: relPath)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }

                let image = self.fileStore.loadImage(at: url)
                let thumb = image?.downscaled(maxDimension: 364)

                DispatchQueue.main.async {
                    self.thumbnails[key] = thumb
                    self.thumbInFlight.remove(key)
                    self.applyThumbnails()
                }
            }
        }
    }

    func applyThumbnails() {
        items = items.map { item in
            switch item {
            case .document(var doc):
                doc.thumbnail = thumbnails[ThumbKey(docID: doc.id, pageIndex: 0)]
                doc.secondThumbnail = thumbnails[ThumbKey(docID: doc.id, pageIndex: 1)]
                return .document(doc)

            case .folder(var folder):
                folder.previewDocuments = folder.previewDocuments.map { preview in
                    var copy = preview
                    copy.thumbnail = thumbnails[ThumbKey(docID: preview.id, pageIndex: 0)]
                    copy.secondThumbnail = thumbnails[ThumbKey(docID: preview.id, pageIndex: 1)]
                    return copy
                }
                return .folder(folder)
            }
        }
    }

    func mapFolder(_ folder: FolderEntity) -> FileFolderItem {
        let docs = (folder.documents as? Set<DocumentEntity>) ?? []

        let previewDocs = docs
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map { mapDocument($0) }

        return FileFolderItem(
            id: folder.id ?? UUID(),
            title: folder.title ?? "Folder",
            createdAt: folder.createdAt,
            isLocked: folder.isLocked,
            lockViaFaceId: folder.lockViaFaceId,
            documentsCount: docs.count,
            previewDocuments: previewDocs,
            passwordHash: folder.passwordHash,
            passwordSalt: folder.passwordSalt
        )
    }

    func mapDocument(_ doc: DocumentEntity) -> FileDocumentItem {
        let pages = (doc.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        let first = pages.first?.imagePath
        let second = pages.count > 1 ? pages[1].imagePath : nil

        let documentType = DocumentTypeEnum(
            rawValue: doc.documentTypeRaw ?? ""
        ) ?? .documents

        return FileDocumentItem(
            id: doc.id ?? UUID(),
            folderID: doc.folder?.id,
            title: doc.title,
            documentType: documentType,
            createdAt: doc.createdAt,
            pageCount: Int(doc.pageCount),
            isLocked: doc.isLocked,
            lockViaFaceId: doc.lockViaFaceId,
            isFavourite: doc.isFavourite,
            sizeInBytes: doc.cachedSize,
            isMerged: isMergedDocument(doc),
            previewDocumentType: previewDocumentType(for: doc),
            firstPagePath: first,
            secondPagePath: second,
            thumbnail: nil,
            secondThumbnail: nil,
            passwordHash: doc.passwordHash,
            passwordSalt: doc.passwordSalt
        )
    }

    func previewDocumentType(for doc: DocumentEntity) -> DocumentTypeEnum {
        let defaultType = DocumentTypeEnum(
            rawValue: doc.documentTypeRaw ?? ""
        ) ?? .documents

        let containerType = DocumentContainerType(
            rawValue: doc.containerTypeRaw
        ) ?? .regular

        guard containerType == .merged else {
            return defaultType
        }

        let pages = (doc.pages as? Set<PageEntity>)?
            .sorted { $0.index < $1.index } ?? []

        guard let firstPage = pages.first else {
            return defaultType
        }

        return DocumentTypeEnum(
            rawValue: firstPage.sourceDocumentTypeRaw
        ) ?? defaultType
    }

    func isMergedDocument(_ doc: DocumentEntity) -> Bool {
        let containerType = DocumentContainerType(
            rawValue: doc.containerTypeRaw
        ) ?? .regular

        return containerType == .merged
    }
}
