import Foundation

enum DocumentFilterType: String, CaseIterable, Identifiable, Codable {
    case original
    case auto
    case perfect
    case blackWhite
    case inverted
    
    var id: String { rawValue }
}

extension DocumentFilterType {
    var title: String {
        switch self {
        case .original:   return "Original"
        case .auto:       return "Auto"
        case .perfect:    return "Perfect"
        case .blackWhite: return "B&W"
        case .inverted:   return "Inverted"
        }
    }
}
