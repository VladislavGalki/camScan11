import Foundation
import CoreData
import UIKit
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var items: [DocumentListItem] = []
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]

    private let store: DocumentsStore

    init() {
        self.store = DocumentsStore()

        // подписки не нужны — store уже @Published, просто прокидываем
        self.items = store.items
        self.thumbnails = store.thumbnails

        // связываем изменения store -> vm
        // (чтобы View подписывался только на VM)
        store.$items
            .sink { [weak self] in self?.items = $0 }
            .store(in: &cancellables)

        store.$thumbnails
            .sink { [weak self] in self?.thumbnails = $0 }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    func delete(docID: UUID) {
        do {
            try store.delete(docID: docID)
        } catch {
            print("❌ delete error:", error)
        }
    }

    func refresh() {
        store.refresh()
    }
}
