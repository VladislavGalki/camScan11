import Foundation
import UIKit

// MARK: - ReorderPageItem

struct ReorderPageItem: Identifiable, Equatable {
    let id: UUID
    let originalIndex: Int
    let title: String
    let documentType: DocumentTypeEnum
    let preview: UIImage?
    let secondPreview: UIImage?
}

// MARK: - ReorderPagesViewModel

@MainActor
final class ReorderPagesViewModel: ObservableObject {
    // MARK: - Published

    @Published private(set) var pages: [ReorderPageItem] = []

    // MARK: - Internal

    var hasChanges: Bool {
        pages.map(\.id) != originalOrder
    }

    // MARK: - Private

    private var originalOrder: [UUID] = []
    private let inputModel: ReorderPagesInputModel
    private let documentRepository: DocumentRepository
    private let imageCompressionService: ImageCompressionService

    // MARK: - Init

    init(inputModel: ReorderPagesInputModel, dependencies: AppDependencies) {
        self.inputModel = inputModel
        self.documentRepository = dependencies.documentRepository
        self.imageCompressionService = dependencies.imageCompressionService
        reload()
    }

    // MARK: - Actions

    func move(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
    }

    func save() -> Bool {
        let newOrder = pages.map(\.id)
        do {
            try documentRepository.reorderPages(
                documentID: inputModel.documentID,
                newOrder: newOrder
            )
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Private

private extension ReorderPagesViewModel {
    func reload() {
        let pageIDs = (try? documentRepository.fetchSortedPageIDs(
            documentID: inputModel.documentID
        )) ?? []

        let pageGroups = (try? documentRepository.loadPreviewInputModel(
            id: inputModel.documentID
        ).pageGroups) ?? []

        let preparedModels = pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: OpenDocumentFramePreparer.preparedFrames(
                    $0.frames,
                    imageCompressionService: imageCompressionService
                )
            )
        }

        pages = zip(pageIDs, preparedModels).enumerated().map { index, pair in
            let (pageID, model) = pair
            return ReorderPageItem(
                id: pageID,
                originalIndex: index,
                title: "Page \(index + 1)",
                documentType: model.documentType,
                preview: model.frames.first?.preview,
                secondPreview: model.frames[safe: 1]?.preview
            )
        }

        originalOrder = pages.map(\.id)
    }
}
