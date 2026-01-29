import Foundation
import SwiftUI

final class ScanUIStateStore: ObservableObject {
    @Published var flashMode: FlashMode = .auto
    @Published var quality: QualityPreset = .hd

    @Published var selectedDocumentType: DocumentTypeEnum = .documents
    @Published var idFrameRectInCameraSpace: CGRect = .zero

    @Published var idCaptureSide: IdCaptureSide = .front
    
    func toggleFlashMode() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        }
    }

//    func toggleDocumentType(_ documentType: DocumentType) {
//        for index in selectedDocumentType.indices {
//            let id = selectedDocumentType[index].id
//            selectedDocumentType[index].isSelected = documentType.id == id
//        }
//
//        if documentType.type == .id {
//            isIdIntroVisible = true
//            selectedIdType = .general
//            idCaptureSide = .front
//        }
//    }

//    private func setupDocumentTypes() {
//        selectedDocumentType = [
//            DocumentType(type: .documents, title: "Скан", isSelected: true),
//            DocumentType(type: .id, title: "Удостоверение", isSelected: false)
//        ]
//    }
}
