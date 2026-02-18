import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home
    case files
    case tools
    case settings
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .files: return "Files"
        case .tools: return "Tools"
        case .settings: return "Settings"
        }
    }
    
    var icon: AppIcon {
        switch self {
        case .home: return .home
        case .files: return .files
        case .tools: return .tools
        case .settings: return .settings
        }
    }
}
