import SwiftUI

// MARK: - Config

struct AppButtonConfig: Hashable {
    enum Style: Hashable {
        case primary
        case secondary
        case immersive
    }
    
    enum Size: Hashable {
        case l, m, s
    }
    
    enum Content: Hashable {
        case title(String)
        case titleWithIcon(title: String, icon: AppIcon, placement: IconPlacement = .leading)
        case iconOnly(AppIcon)
        
        enum IconPlacement: Hashable {
            case leading, trailing
        }
    }
    
    var style: Style
    var size: Size
    var content: Content
    var isFullWidth: Bool = false
    
    init(
        content: Content,
        style: Style,
        size: Size,
        isFullWidth: Bool = false
    ) {
        self.content = content
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
    }
}

private extension AppButtonConfig.Content {
    var kind: ButtonContentKind {
        switch self {
        case .title: return .text
        case .titleWithIcon: return .textWithIcon
        case .iconOnly: return .iconOnly
        }
    }
}

public enum ButtonContentKind {
    case text, textWithIcon, iconOnly
}

// MARK: - AppButton

struct AppButton: View {
    @Environment(\.appButtonEnabled) private var appButtonEnabled
    
    let config: AppButtonConfig
    let action: () -> Void
    
    init(config: AppButtonConfig, action: @escaping () -> Void) {
        self.config = config
        self.action = action
    }
    
    var body: some View {
        Button {
            guard appButtonEnabled else { return }
            action()
        } label: {
            label
        }
        .buttonStyle(
            AppButtonStyle(
                variant: config.style,
                size: config.size,
                isFullWidth: config.isFullWidth,
                contentKind: config.content.kind,
                isEnabled: appButtonEnabled
            )
        )
    }
    
    @ViewBuilder
    private var label: some View {
        switch config.content {
        case let .title(title):
            Text(title)
                .lineLimit(1)
        case let .titleWithIcon(title, icon, placement):
            HStack(spacing: 8) {
                if placement == .leading {
                    AppIconView(icon: icon, configSize: config.size)
                }
                
                Text(title)
                    .lineLimit(1)
                
                if placement == .trailing {
                    AppIconView(icon: icon, configSize: config.size)
                }
            }
        case .iconOnly(let icon):
            AppIconView(icon: icon, configSize: config.size)
        }
    }
}

// MARK: - ButtonStyle

struct AppButtonStyle: ButtonStyle {
    let variant: AppButtonConfig.Style
    let size: AppButtonConfig.Size
    let isFullWidth: Bool
    let contentKind: ButtonContentKind
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let m = size.metrics
        let padding = m.hPadding(for: contentKind)
        
        return configuration.label
            .appTextStyle(m.textStyle)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(padding)
            .contentShape(Capsule())
            .background(background(isEnabled: isEnabled))
            .foregroundStyle(foreground(isEnabled: isEnabled))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
    
    private func background(isEnabled: Bool) -> Color {
        switch variant {
        case .primary:
            return isEnabled ? .bg(.accent) : .bg(.accentDisabled)
        case .secondary:
            return .bg(.control)
        case .immersive:
            return .bg(.controlImmersive)
        }
    }
    
    private func foreground(isEnabled: Bool) -> Color {
        switch variant {
        case .primary:
            return isEnabled ? .text(.onAccent) : .text(.onAccentDisabled)
        case .secondary:
            return isEnabled ? .text(.accent) : .text(.accentDisabled)
        case .immersive:
            return isEnabled ? .elements(.onImmersive) : .elements(.onImmersive)
        }
    }
}

// MARK: - Metrics

private struct ButtonMetrics {
    let textStyle: AppTextStyle
    let horizontalPaddingText: EdgeInsets
    let horizontalPaddingTextWithIcon: EdgeInsets
    let horizontalPaddingIconOnly: EdgeInsets
    
    func hPadding(for kind: ButtonContentKind) -> EdgeInsets {
        switch kind {
        case .text: return horizontalPaddingText
        case .textWithIcon: return horizontalPaddingTextWithIcon
        case .iconOnly: return horizontalPaddingIconOnly
        }
    }
}

private extension AppButtonConfig.Size {
    var metrics: ButtonMetrics {
        switch self {
        case .l:
            return ButtonMetrics(
                textStyle: .bodyPrimary,
                horizontalPaddingText: EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18),
                horizontalPaddingTextWithIcon: EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 18),
                horizontalPaddingIconOnly: EdgeInsets(top: 13, leading: 13, bottom: 13, trailing: 13)
            )
        case .m:
            return ButtonMetrics(
                textStyle: .bodySecondary,
                horizontalPaddingText: EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16),
                horizontalPaddingTextWithIcon: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 16),
                horizontalPaddingIconOnly: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            )
        case .s:
            return ButtonMetrics(
                textStyle: .bodySecondary,
                horizontalPaddingText: EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8),
                horizontalPaddingTextWithIcon: EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8),
                horizontalPaddingIconOnly: EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            )
        }
    }
}
