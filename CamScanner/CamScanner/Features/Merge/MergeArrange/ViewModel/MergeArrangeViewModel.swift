import Foundation
import UIKit

@MainActor
final class MergeArrangeViewModel: ObservableObject {

    @Published var items: [DocumentListItem] = []
    @Published var thumbnails: [UUID: UIImage] = [:]

    private let store = DocumentsStore()

    init(docIDs: [UUID]) {
        // берём данные из store
        let all = store.items
        self.items = docIDs.compactMap { id in all.first(where: { $0.id == id }) }
        self.thumbnails = store.thumbnails
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func title(for item: DocumentListItem) -> String {
        let kind = item.kind.lowercased()
        if kind == "id" { return "\(item.idType ?? "ID") • \(item.pageCount) стр." }
        return "Скан • \(item.pageCount) стр."
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
                print("❌ merge error:", error)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
