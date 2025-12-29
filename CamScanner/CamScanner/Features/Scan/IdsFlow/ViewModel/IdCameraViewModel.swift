import SwiftUI

final class IdCameraViewModel: ObservableObject {
    @Published var documentType: [IdCameraDocumentType] = []
    
    init() {
        setupDocumentType()
    }
    
    func getSelectedDocumentType() -> IdCameraDocumentType? {
        documentType.first(where: { $0.isSelected })
    }
    
    func toggleDocumentType(_ document: IdCameraDocumentType) {
        for index in documentType.indices {
            let id = documentType[index].id
            documentType[index].isSelected = document.id == id ? true : false
        }
    }
    
    private func setupDocumentType() {
        documentType = [
            IdCameraDocumentType(title: "Общий", isSelected: true),
            IdCameraDocumentType(title: "Идентификационная", isSelected: false),
            IdCameraDocumentType(title: "Водительские права", isSelected: false),
            IdCameraDocumentType(title: "Пасспорт", isSelected: false),
            IdCameraDocumentType(title: "Банковская карта", isSelected: false),
        ]
    }
}
