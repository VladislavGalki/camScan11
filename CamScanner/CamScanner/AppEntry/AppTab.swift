import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home
    case files
    case tools
    case profile

    var title: String {
        switch self {
        case .home: return "Главная"
        case .files: return "Файлы"
        case .tools: return "Инструменты"
        case .profile: return "Я"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .files: return "doc.text"
        case .tools: return "square.grid.2x2"
        case .profile: return "person"
        }
    }
}
