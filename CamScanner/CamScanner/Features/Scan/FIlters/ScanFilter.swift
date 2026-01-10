import Foundation

enum PreviewFilter: CaseIterable, Identifiable, Equatable {
    case original
    case omnifix
    case noShadow
    case noHandwriting
    case brighter
    case enhance
    case eco
    case grayscale
    case blackWhite
    case invert

    var id: String { title }

    var title: String {
        switch self {
        case .original: return "Оригинал"
        case .omnifix: return "OmniFix"
        case .noShadow: return "Без тени"
        case .noHandwriting: return "Без почерка"
        case .brighter: return "Светлее"
        case .enhance: return "Улучшить"
        case .eco: return "Эко"
        case .grayscale: return "Градации серого"
        case .blackWhite: return "Ч/Б"
        case .invert: return "Отменить"
        }
    }
    
    var persistKey: String {
        switch self {
        case .original: return "original"
        case .omnifix: return "omnifix"
        case .noShadow: return "noShadow"
        case .noHandwriting: return "noHandwriting"
        case .brighter: return "brighter"
        case .enhance: return "enhance"
        case .eco: return "eco"
        case .grayscale: return "grayscale"
        case .blackWhite: return "blackWhite"
        case .invert: return "invert"
        }
    }

    var isOmnifix: Bool { self == .omnifix }
}

extension PreviewFilter {
    static func fromPersistKey(_ key: String?) -> PreviewFilter? {
        guard let key else { return nil }
        return Self.allCases.first(where: { $0.persistKey == key })
    }
}
