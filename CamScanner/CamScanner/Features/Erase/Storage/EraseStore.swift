import Foundation
import CoreData
import Combine
import UIKit

final class EraseStore {
    var previewModelsPublisher: AnyPublisher<[ScanPreviewModel], Never> {
        openDocumentStore.previewModelsPublisher
    }

    private let openDocumentStore: OpenDocumentStore
    private let documentRepository: DocumentRepository
    private let documentID: UUID

    init(
        documentID: UUID,
        documentRepository: DocumentRepository,
        context: NSManagedObjectContext
    ) {
        self.documentID = documentID
        self.documentRepository = documentRepository
        self.openDocumentStore = OpenDocumentStore(
            documentID: documentID,
            context: context,
            documentRepository: documentRepository
        )
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
