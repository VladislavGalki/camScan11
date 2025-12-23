import Foundation

enum DocumentType: String, CaseIterable, Identifiable {
    case scan = "Скан"
    var id: String { rawValue }
}
