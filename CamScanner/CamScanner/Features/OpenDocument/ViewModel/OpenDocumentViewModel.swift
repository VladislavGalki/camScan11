import Foundation
import Combine
import UIKit

@MainActor
final class OpenDocumentViewModel: ObservableObject {
    @Published var models: [ScanPreviewModel] = []
    @Published var selectedIndex: Int = 0
    @Published var title: String = ""

    private let inputModel: OpenDocumentInputModel
    private let store: OpenDocumentStore
    private let documentRepository = DocumentRepository.shared

    private var cancellables = Set<AnyCancellable>()

    init(inputModel: OpenDocumentInputModel) {
        self.inputModel = inputModel
        self.store = OpenDocumentStore(documentID: inputModel.documentID)

        subscribe()
        bootstrap()
    }

    private func bootstrap() {
        if let title = try? documentRepository.fetchDocumentTitle(id: inputModel.documentID) {
            self.title = title
        }
    }

    private func subscribe() {
        store.previewModelsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                self?.models = models
                
                if let self {
                    self.selectedIndex = min(self.selectedIndex, max(models.count - 1, 0))
                }
            }
            .store(in: &cancellables)
    }
}

extension OpenDocumentViewModel {
    func updateSelectedIndex(_ index: Int) {
        selectedIndex = index
    }
    
    func makeCropperInputModel() -> ScanCropperInputModel {
        ScanCropperInputModel(
            pageGroups: models.map {
                PreviewPageGroup(
                    documentType: $0.documentType,
                    frames: $0.frames
                )
            }
        )
    }
    
    func applyCropOutput(_ output: ScanPreviewInputModel) {
        models = output.pageGroups.map {
            ScanPreviewModel(
                documentType: $0.documentType,
                frames: $0.frames
            )
        }

        selectedIndex = min(selectedIndex, max(models.count - 1, 0))
    }

    func rotatePage(at index: Int) {
        guard models.indices.contains(index) else { return }

        var page = models[index]

        page.frames = page.frames.map { frame in
            var f = frame
            var newState = f.currentFilter
            newState.rotationAngle += .pi / 2
            f.applyFilter(newState)

            if let base = f.displayBase {
                f.preview = FilterRenderer.shared.render(
                    image: base,
                    state: newState
                )
            }

            return f
        }

        DispatchQueue.main.async { [weak self] in
            self?.models[index] = page
        }
    }
}

// MARK: - Helper

extension OpenDocumentViewModel {
    
}
