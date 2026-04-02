import Foundation
import UIKit

@MainActor
final class OpenDocumentSelectPagesViewModel: ObservableObject {
    @Published private(set) var title: String = ""
    @Published private(set) var pages: [OpenDocumentSelectablePageItem] = []
    @Published var selectedPageIndexes: Set<Int> = []

    private let inputModel: OpenDocumentSelectPagesInputModel
    private let documentRepository = DocumentRepository.shared

    init(inputModel: OpenDocumentSelectPagesInputModel) {
        self.inputModel = inputModel
        reload()
    }

    var selectedCount: Int {
        selectedPageIndexes.count
    }

    var hasSelectedPages: Bool {
        !selectedPageIndexes.isEmpty
    }

    var isAllSelected: Bool {
        !pages.isEmpty && selectedPageIndexes.count == pages.count
    }

    var selectedRawPageIndices: [Int] {
        rawPageIndices(for: selectedPageIndexes)
    }

    func toggleSelection(index: Int) {
        if selectedPageIndexes.contains(index) {
            selectedPageIndexes.remove(index)
        } else {
            selectedPageIndexes.insert(index)
        }
    }

    func toggleSelectAll() {
        if isAllSelected {
            selectedPageIndexes.removeAll()
        } else {
            selectedPageIndexes = Set(pages.map(\.index))
        }
    }

    func makeShareInputModel() -> ShareInputModel? {
        let selectedPages = pages
            .filter { selectedPageIndexes.contains($0.index) }
            .sorted { $0.index < $1.index }
            .map(\.model)

        guard !selectedPages.isEmpty else { return nil }

        return ShareInputModel(
            documentName: title,
            documentType: selectedPages.first?.documentType ?? .documents,
            pages: selectedPages
        )
    }

    func makeMoveInputModel() -> OpenDocumentSelectPagesMoveInputModel? {
        let rawIndices = selectedRawPageIndices
        guard !rawIndices.isEmpty else { return nil }

        return OpenDocumentSelectPagesMoveInputModel(
            sourceDocumentID: inputModel.documentID,
            sourceDocumentTitle: title,
            selectedRawPageIndices: rawIndices,
            selectedItemsCount: selectedCount
        )
    }

    func deleteSelectedPages() -> OpenDocumentSelectPagesDeleteResult {
        let indexesToDelete = selectedRawPageIndices.sorted(by: >)
        guard !indexesToDelete.isEmpty else { return .failed }

        do {
            let totalRawPages = pages.reduce(0) { $0 + max(1, $1.model.frames.count) }

            if indexesToDelete.count == totalRawPages {
                try documentRepository.deleteDocument(id: inputModel.documentID)
                selectedPageIndexes.removeAll()
                NotificationCenter.default.post(
                    name: .openDocumentPreviewDidChange,
                    object: nil,
                    userInfo: ["documentID": inputModel.documentID]
                )
                return .deletedDocument
            }

            for index in indexesToDelete {
                try documentRepository.deletePage(documentID: inputModel.documentID, at: index)
            }

            selectedPageIndexes.removeAll()
            NotificationCenter.default.post(
                name: .openDocumentPreviewDidChange,
                object: nil,
                userInfo: ["documentID": inputModel.documentID]
            )
            reload()
            return .deletedPages
        } catch {
            return .failed
        }
    }

    func reload() {
        title = (try? documentRepository.fetchDocumentTitle(id: inputModel.documentID)) ?? ""

        let pageGroups = (try? documentRepository.loadPreviewInputModel(id: inputModel.documentID).pageGroups) ?? []

        let preparedModels = pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: OpenDocumentFramePreparer.preparedFrames($0.frames)
            )
        }

        pages = preparedModels.enumerated().map { index, model in
            OpenDocumentSelectablePageItem(index: index, model: model)
        }

        selectedPageIndexes = selectedPageIndexes.intersection(Set(pages.map(\.index)))
    }

    func reloadAndClearSelection() {
        selectedPageIndexes.removeAll()
        reload()
    }
}

enum OpenDocumentSelectPagesDeleteResult {
    case deletedPages
    case deletedDocument
    case failed
}

struct OpenDocumentSelectablePageItem: Identifiable {
    let index: Int
    let model: ScanPreviewModel

    var id: Int { index }

    var firstPreview: UIImage? {
        model.frames.first?.preview
    }

    var secondPreview: UIImage? {
        model.frames[safe: 1]?.preview
    }
}

private extension OpenDocumentSelectPagesViewModel {
    func rawPageIndices(for selectedModelIndexes: Set<Int>) -> [Int] {
        guard !selectedModelIndexes.isEmpty else { return [] }

        var result: [Int] = []
        var currentRawIndex = 0

        for page in pages {
            let frameCount = max(1, page.model.frames.count)

            if selectedModelIndexes.contains(page.index) {
                result.append(contentsOf: Array(currentRawIndex..<(currentRawIndex + frameCount)))
            }

            currentRawIndex += frameCount
        }

        return result
    }
}
