import Foundation
import SwiftUI

enum IdDocumentTypeEnum: CaseIterable, Identifiable, Equatable {
    case general, identification, driverLicense, passport, bankCard

    var id: String { title }

    var title: String {
        switch self {
        case .general: return "Общий"
        case .identification: return "Идентификационная"
        case .driverLicense: return "Водительские права"
        case .passport: return "Паспорт"
        case .bankCard: return "Банковская карта"
        }
    }
}

final class ScanUIStateStore: ObservableObject {
    @Published var flashMode: FlashMode = .off
    @Published var quality: QualityPreset = .hd
    @Published var filter: ScanFilter = .original
    @Published var captureMode: CaptureMode = .single

    @Published var selectedDocumentType: [DocumentType] = []

    // ID flow
    @Published var isIdIntroVisible: Bool = true
    @Published var selectedIdType: IdDocumentTypeEnum = .general

    @Published var idFrameRectInCameraSpace: CGRect = .zero
    
    init() {
        setupDocumentTypes()
    }

    func getSelectedDocumentType() -> DocumentTypeEnum {
        selectedDocumentType.first(where: { $0.isSelected })?.type ?? .scan
    }

    func toggleDocumentType(_ documentType: DocumentType) {
        for index in selectedDocumentType.indices {
            let id = selectedDocumentType[index].id
            selectedDocumentType[index].isSelected = documentType.id == id
        }
        
        if documentType.type == .id {
            isIdIntroVisible = true
            selectedIdType = .general
        }
    }

    private func setupDocumentTypes() {
        selectedDocumentType = [
            DocumentType(type: .scan, title: "Скан", isSelected: true),
            DocumentType(type: .id, title: "Удостоверение", isSelected: false)
        ]
    }
}
