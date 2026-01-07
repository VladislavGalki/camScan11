import Foundation

enum DocumentExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case jpeg = "JPEG"
    case png = "PNG"
    case longImage = "Long Image"
    case ppt = "PPT (soon)"
    case word = "Word (soon)"
    case excel = "Excel (soon)"

    var id: String { rawValue }

    var isImplemented: Bool {
        switch self {
        case .pdf, .jpeg, .png, .longImage:
            return true
        case .ppt, .word, .excel:
            return false
        }
    }
}
