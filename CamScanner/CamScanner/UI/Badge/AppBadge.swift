import SwiftUI

struct AppBadgeConfig {
    enum Style {
        case count(Int)
        case status(String)
    }
    
    var style: Style
    
    init(style: Style) {
        self.style = style
    }
}

struct AppBadge: View {
    let config: AppBadgeConfig
    let action: () -> Void
    
    init(config: AppBadgeConfig, action: @escaping () -> Void) {
        self.config = config
        self.action = action
    }
    
    var body: some View {
        switch config.style {
        case let .count(count):
            badgeCountView(count)
                .onTapGesture {
                    action()
                }
        case let .status(text):
            statusBadgeView(text)
        }
    }
    
    private func badgeCountView(_ count: Int) -> some View {
        Circle()
            .overlay {
                Text(String(count))
                    .appTextStyle(.meta)
                    .foregroundStyle(.text(.onAccent))
            }
            .frame(width: 20, height: 20)
            .foregroundStyle(.bg(.accent))
            .appBorderModifier(.border(.primaryImmersive), width: 1, radius: 100, corners: .allCorners)
    }
    
    private func statusBadgeView(_ text: String) -> some View {
        Text(text)
            .appTextStyle(.meta)
            .foregroundStyle(.text(.accent))
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                Rectangle()
                    .foregroundStyle(.bg(.accentSubtle))
            )
            .cornerRadius(6, corners: .allCorners)
    }
}
