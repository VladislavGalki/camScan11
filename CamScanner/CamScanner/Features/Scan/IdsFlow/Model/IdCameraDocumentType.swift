import Foundation

struct IdCameraDocumentType: Identifiable {
    var id: UUID = UUID()
    let title: String
    var isSelected: Bool
}
