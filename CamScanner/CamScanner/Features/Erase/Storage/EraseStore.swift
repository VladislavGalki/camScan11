import Foundation
import Combine
import UIKit

final class EraseStore {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        openDocumentStore.previewModelsPublisher
    }

    private let openDocumentStore: OpenDocumentStore
    private let documentRepository = DocumentRepository.shared
    private let documentID: UUID

    init(documentID: UUID) {
        self.documentID = documentID
        self.openDocumentStore = OpenDocumentStore(documentID: documentID)
    }

    func saveErasedPages(_ pageImages: [(pageIndex: Int, image: UIImage)]) throws {
        try documentRepository.saveErasedPageImage(
            documentID: documentID,
            pageImages: pageImages
        )

        NotificationCenter.default.post(
            name: .openDocumentPreviewDidChange,
            object: nil,
            userInfo: ["documentID": documentID]
        )
    }
}
