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

extension DocumentFilterType {
    var defaultSliderValue: Double {
        switch self {
        case .original: return 0.0
        case .auto: return 0.1
        case .perfect: return 0.4
        case .blackWhite: return 0.8
        case .inverted: return 0.2
        }
    }

    var sliderRange: ClosedRange<Double> {
        switch self {
        case .original:
            return 0...1

        case .auto:
            return -0.5...0.5

        case .perfect:
            return -0.4...0.6

        case .blackWhite:
            return 0.6...2.8

        case .inverted:
            return -0.6...0.6
        }
    }
}
