import SwiftUI

@MainActor
final class MoveDocumentsViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var items: [FilesGridItem] = []
    @Published var currentFolderID: UUID?
    
    let viewMode: FilesViewMode

    private var stack: [UUID] = []
    private let documentIDs: [UUID]
    
    private var thumbInFlight = Set<ThumbKey>()
    private var thumbnails: [ThumbKey: UIImage] = [:]

    private let documentRepository: DocumentRepository
    private let fileStore: FileStore

    let onMove: ([UUID], UUID?) -> Void

    init(
        viewMode: FilesViewMode,
        folderId: UUID?,
        documentIDs: [UUID],
        onMove: @escaping ([UUID], UUID?) -> Void,
        dependencies: AppDependencies
    ) {
        self.viewMode = viewMode
        self.documentIDs = documentIDs
        self.onMove = onMove
        self.documentRepository = dependencies.documentRepository
        self.fileStore = dependencies.fileStore

        if let folderId {
            openFolderTapped(folderId)
        } else {
            loadRootItems()
        }
    }
    
    private func loadRootItems() {
        thumbnails.removeAll()
        thumbInFlight.removeAll()
        currentFolderID = nil
        stack.removeAll()

        let folders = documentRepository.fetchFolders()

        items = folders.map {
            .folder(mapFolder($0))
        }
        
        loadThumbnails()
    }
    
    private func loadThumbnails() {
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
    
    private func loadThumbs(for doc: FileDocumentItem) {
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

                let img = self.fileStore.loadImage(at: url)
                let thumb = img?.downscaled(maxDimension: 364)

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
            switch item {
            case .document(var doc):
                doc.thumbnail = thumbnails[
                    ThumbKey(docID: doc.id, pageIndex: 0)
                ]

                doc.secondThumbnail = thumbnails[
                    ThumbKey(docID: doc.id, pageIndex: 1)
                ]

                return .document(doc)
            case .folder(var folder):
                folder.previewDocuments = folder.previewDocuments.map { preview in
                    var copy = preview

                    copy.thumbnail = thumbnails[
                        ThumbKey(docID: preview.id, pageIndex: 0)
                    ]

                    copy.secondThumbnail = thumbnails[
                        ThumbKey(docID: preview.id, pageIndex: 1)
                    ]

                    return copy
                }
                return .folder(folder)
            }
        }
    }
    
    func openFolderTapped(_ id: UUID) {
        thumbnails.removeAll()
        thumbInFlight.removeAll()
        
        stack.append(id)
        currentFolderID = id

        let docs = documentRepository.fetchDocuments(in: id)

        items = docs.map {
            .document(mapDocument($0))
        }
        
        loadThumbnails()
    }
    
    func goBackTapped() {
        guard !stack.isEmpty else { return }

        stack.removeLast()

        if let id = stack.last {
            openFolderTapped(id)
        } else {
            currentFolderID = nil
            loadRootItems()
        }
    }
    
    func handleFolderCreated(folderName: String) {
        do {
            try documentRepository.createFolder(title: folderName)
            loadRootItems()
        } catch {}
    }
    
    func handleMoveAction() {
        onMove(documentIDs, currentFolderID)
    }
}

extension MoveDocumentsViewModel {
    private func mapFolder(_ folder: FolderEntity) -> FileFolderItem {
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
    
    private func mapDocument(_ doc: DocumentEntity) -> FileDocumentItem {
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
    
    private func previewDocumentType(for doc: DocumentEntity) -> DocumentTypeEnum {
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
    
    private func isMergedDocument(_ doc: DocumentEntity) -> Bool {
        let containerType = DocumentContainerType(
            rawValue: doc.containerTypeRaw
        ) ?? .regular

        return containerType == .merged
    }
}
