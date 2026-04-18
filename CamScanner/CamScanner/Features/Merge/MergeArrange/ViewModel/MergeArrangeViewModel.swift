import Foundation
import UIKit
import Combine

@MainActor
final class MergeArrangeViewModel: ObservableObject {

    @Published var items: [DocumentListItem] = []
    @Published var thumbnails: [UUID: UIImage] = [:]

    private let store = HomeDocumentsStore()
    private let docIDs: [UUID]
    private var cancellables: Set<AnyCancellable> = []

    init(docIDs: [UUID]) {
        self.docIDs = docIDs

    }

    func onAppear() {
        //store.refresh()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func title(for item: DocumentListItem) -> String {
        return ""
//        let kind = item.kind.lowercased()
    }

    func mergeAndSave(completion: @escaping (UUID?) -> Void) {
        let orderedIDs = items.map { $0.id }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newID = try DocumentMergeService.shared.mergeDocuments(docIDs: orderedIDs)
                DispatchQueue.main.async {
                    completion(newID)
                }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
