import SwiftUI

// MARK: - Public API

enum AppTextStyle: CaseIterable {
    case screenTitle
    case sectionTitle
    case itemTitle
    case bodyPrimary
    case bodySecondary
    case meta
    case helperText
    case tabBar
}

extension Font {
    static func app(_ style: AppTextStyle) -> Font {
        let t = style.typography
        return .system(size: t.size, weight: t.weight)
    }
}

extension View {
    func appTextStyle(
        _ style: AppTextStyle,
        multilineAlignment: TextAlignment = .leading
    ) -> some View {
        modifier(TextStyleModifier(style: style, multilineAlignment: multilineAlignment))
    }
}

// MARK: - Implementation

private struct Typography {
    let size: CGFloat
    let lineHeight: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat

    var lineSpacing: CGFloat {
        max(0, lineHeight - size)
    }
}

private extension AppTextStyle {

    var typography: Typography {
        switch self {

        case .screenTitle:
            return .init(size: 34, lineHeight: 42, weight: .bold, tracking: 0.4)

        case .sectionTitle:
            return .init(size: 22, lineHeight: 28, weight: .bold, tracking: -0.26)

        case .itemTitle:
            return .init(size: 17, lineHeight: 22, weight: .semibold, tracking: -0.43)

        case .bodyPrimary:
            return .init(size: 17, lineHeight: 22, weight: .regular, tracking: -0.43)

        case .bodySecondary:
            return .init(size: 15, lineHeight: 20, weight: .regular, tracking: -0.23)

        case .meta:
            return .init(size: 12, lineHeight: 16, weight: .medium, tracking: 0.0)

        case .helperText:
            return .init(size: 11, lineHeight: 14, weight: .regular, tracking: 0.06)

        case .tabBar:
            return .init(size: 10, lineHeight: 12, weight: .semibold, tracking: -0.1)
        }
    }
}

private struct TextStyleModifier: ViewModifier {

    let style: AppTextStyle
    let multilineAlignment: TextAlignment

    func body(content: Content) -> some View {

        let t = style.typography

        return content
            .font(.app(style))
            .tracking(t.tracking)
            .lineSpacing(t.lineSpacing)
            .multilineTextAlignment(multilineAlignment)
    }
}
