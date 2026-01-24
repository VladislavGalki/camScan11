import Foundation
import UIKit
import Combine

@MainActor
final class MergeArrangeViewModel: ObservableObject {

    @Published var items: [DocumentListItem] = []
    @Published var thumbnails: [UUID: UIImage] = [:]

    private let store = DocumentsStore()
    private let docIDs: [UUID]
    private var cancellables: Set<AnyCancellable> = []

    init(docIDs: [UUID]) {
        self.docIDs = docIDs

        // 1) Слушаем items → пересобираем items только из выбранных id (в нужном порядке)
//        store.$items
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] all in
//                guard let self else { return }
//                self.items = self.docIDs.compactMap { id in
//                    all.first(where: { $0.id == id })
//                }
//            }
//            .store(in: &cancellables)
//
//        // 2) Слушаем thumbnails → просто прокидываем
//        store.$thumbnails
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] thumbs in
//                self?.thumbnails = thumbs
//            }
//            .store(in: &cancellables)
//
//        // на старте — попробуем сразу заполнить тем, что уже есть
//        self.items = docIDs.compactMap { id in store.items.first(where: { $0.id == id }) }
//        self.thumbnails = store.thumbnails
    }

    func onAppear() {
        // важно дернуть refresh, чтобы FRC сделал fetch (если вдруг init случился до fetch)
        //store.refresh()
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
