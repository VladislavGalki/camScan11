import Foundation

enum DocumentTypeEnum: String, CaseIterable, Identifiable {
    case qrCode
    case documents
    case idCard
    case passport
    case driverLicense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .qrCode:        return "QR Code"
        case .documents:     return "Documents"
        case .idCard:        return "ID Card"
        case .passport:      return "Passport"
        case .driverLicense: return "Driver license"
        }
    }

    var requiresBackSide: Bool {
        switch self {
        case .idCard, .driverLicense:
            return true
        case .passport, .documents, .qrCode:
            return false
        }
    }

    var isScan: Bool { self == .documents }
    var isID: Bool { self != .documents }
}
