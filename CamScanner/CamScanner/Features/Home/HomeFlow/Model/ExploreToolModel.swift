import Foundation

public struct ExploreToolModel: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let type: ToolType
    public let icon: AppIcon
    public let title: String
    
    public init(type: ToolType, icon: AppIcon, title: String) {
        self.type = type
        self.icon = icon
        self.title = title
    }
    
    public enum ToolType {
        case recognize
        case addText
        case erase
        case translate
        case signature
        case watermart
        case cloudStorage
    }
}
