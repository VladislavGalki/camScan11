import Foundation
import SwiftUI

final class ScanUIStateStore: ObservableObject {
    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single
    @Published var selectedDocumentType: [DocumentType] = []
    
    init() {
        setupDocumentTypes()
    }
    
    func getSelectedDocumentType() -> DocumentTypeEnum {
        selectedDocumentType.first(where: { $0.isSelected })?.type ?? .scan
    }
    
    func toggleDocumentType(_ documentType: DocumentType) {
        for index in selectedDocumentType.indices {
            let id = selectedDocumentType[index].id
            selectedDocumentType[index].isSelected = documentType.id == id ? true : false
        }
    }
    
    private func setupDocumentTypes() {
        selectedDocumentType = [
            DocumentType(type: .scan, title: "Скан", isSelected: true),
            DocumentType(type: .id, title: "Удостоверение", isSelected: false)
        ]
    }
}
