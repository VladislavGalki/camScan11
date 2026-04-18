import Foundation
import Combine
import UIKit

@MainActor
final class MergeSelectViewModel: ObservableObject {

    @Published private(set) var items: [DocumentListItem] = []
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]

    @Published private(set) var selected: Set<UUID> = []
    private(set) var selectedInOrder: [UUID] = []

    private let store = HomeDocumentsStore()
    private var cancellables: Set<AnyCancellable> = []

    init() {
//        items = store.items
//        thumbnails = store.thumbnails
//
//        store.$items
//            .sink { [weak self] in self?.items = $0 }
//            .store(in: &cancellables)
//
//        store.$thumbnails
//            .sink { [weak self] in self?.thumbnails = $0 }
//            .store(in: &cancellables)
    }

    func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
            selectedInOrder.removeAll { $0 == id }
        } else {
            selected.insert(id)
            selectedInOrder.append(id)
        }
    }
}
