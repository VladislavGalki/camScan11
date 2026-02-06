import Foundation

final class ScanPreviewViewModel: ObservableObject {
    @Published var scanPreviewModel: [ScanPreviewModel] = []
    
    private let inputModel: ScanPreviewInputModel
    
    init(inputModel: ScanPreviewInputModel) {
        self.inputModel = inputModel
        
        bootstrap()
    }
    
    // MARK: - Public
    
    func rotatePage(at index: Int) {
        guard scanPreviewModel.indices.contains(index) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.scanPreviewModel[index].rotateRight()
        }
    }
    
    // MARK: - Private
    
    private func bootstrap() {
        var result: [ScanPreviewModel] = []
        inputModel.pages.forEach { entry in
            let type = entry.key
            let frames = entry.value.filter { $0.preview != nil }
            if type == .documents {
                frames.forEach {
                    result.append(
                        ScanPreviewModel(
                            documentType: type,
                            frames: [$0]
                        )
                    )
                }
            } else {
                result.append(
                    ScanPreviewModel(
                        documentType: type,
                        frames: frames
                    )
                )
            }
        }
        
        scanPreviewModel = result
    }
}
