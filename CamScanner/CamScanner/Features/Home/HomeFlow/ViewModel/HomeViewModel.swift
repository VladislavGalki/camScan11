import Foundation
import CoreData
import UIKit
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    @Published private(set) var items: [DocumentListItem] = []
    @Published private(set) var exploreToolModel: [ExploreToolModel] = []
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
        
        buildLayout()
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

extension HomeViewModel {
    private func buildLayout() {
        exploreToolModel = [
            ExploreToolModel(type: .recognize, icon: .recognizeImage, title: "Recognize text"),
            ExploreToolModel(type: .addText, icon: .addTextImage, title: "Add text"),
            ExploreToolModel(type: .erase, icon: .eraseImage, title: "Erase"),
            ExploreToolModel(type: .translate, icon: .translateImage, title: "Translate text"),
            ExploreToolModel(type: .signature, icon: .signatureImage, title: "Signature"),
            ExploreToolModel(type: .watermart, icon: .watermarkImage, title: "Watermark"),
            ExploreToolModel(type: .cloudStorage, icon: .cloudImage, title: "Cloud Storage")
        ]
    }
}
