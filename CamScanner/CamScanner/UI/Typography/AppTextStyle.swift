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
    static func app(_ style: AppTextStyle, size: CGFloat? = nil) -> Font {
        let t = style.typography
        return .system(
            size: size ?? t.size,
            weight: t.weight,
            design: .default
        )
    }
}

extension View {
    func appTextStyle(_ style: AppTextStyle, multilineAlignment: TextAlignment = .leading) -> some View {
        modifier(TextStyleModifier(style: style, multilineAlignment: multilineAlignment))
    }
}

// MARK: - Implementation

private struct Typography {
    let size: CGFloat
    let lineHeight: CGFloat
    let weight: Font.Weight
    let tracking: CGFloat
    let relativeTo: Font.TextStyle

    var lineSpacing: CGFloat { max(0, lineHeight - size) }
}

private extension AppTextStyle {
    var typography: Typography {
        switch self {
        case .screenTitle:
            return .init(size: 34, lineHeight: 42, weight: .bold, tracking: 0.4, relativeTo: .largeTitle)
        case .sectionTitle:
            return .init(size: 22, lineHeight: 28, weight: .bold, tracking: -0.26, relativeTo: .title3)
        case .itemTitle:
            return .init(size: 17, lineHeight: 22, weight: .semibold, tracking: -0.43, relativeTo: .headline)
        case .bodyPrimary:
            return .init(size: 17, lineHeight: 22, weight: .regular, tracking: -0.43, relativeTo: .body)
        case .bodySecondary:
            return .init(size: 15, lineHeight: 20, weight: .regular, tracking: -0.23, relativeTo: .subheadline)
        case .meta:
            return .init(size: 12, lineHeight: 16, weight: .medium, tracking: 0.0, relativeTo: .footnote)
        case .helperText:
            return .init(size: 11, lineHeight: 14, weight: .regular, tracking: 0.06, relativeTo: .caption2)
        case .tabBar:
            return .init(size: 10, lineHeight: 12, weight: .semibold, tracking: -0.1, relativeTo: .caption2)
        }
    }
}

private struct TextStyleModifier: ViewModifier {
    let style: AppTextStyle
    let multilineAlignment: TextAlignment

    private let base: Typography

    // Dynamic Type scaling (кроме Tab bar)
    @ScaledMetric private var scaledSize: CGFloat
    @ScaledMetric private var scaledLineHeight: CGFloat
    @ScaledMetric private var scaledTracking: CGFloat

    init(style: AppTextStyle, multilineAlignment: TextAlignment) {
        self.style = style
        self.multilineAlignment = multilineAlignment

        let t = style.typography
        self.base = t

        // Для Tab bar оставляем фикс по макету (не скейлим)
        if style == .tabBar {
            self._scaledSize = ScaledMetric(wrappedValue: t.size, relativeTo: .body)
            self._scaledLineHeight = ScaledMetric(wrappedValue: t.lineHeight, relativeTo: .body)
            self._scaledTracking = ScaledMetric(wrappedValue: t.tracking, relativeTo: .body)
        } else {
            self._scaledSize = ScaledMetric(wrappedValue: t.size, relativeTo: t.relativeTo)
            self._scaledLineHeight = ScaledMetric(wrappedValue: t.lineHeight, relativeTo: t.relativeTo)
            self._scaledTracking = ScaledMetric(wrappedValue: t.tracking, relativeTo: t.relativeTo)
        }
    }

    func body(content: Content) -> some View {
        let size = (style == .tabBar) ? base.size : scaledSize
        let lineHeight = (style == .tabBar) ? base.lineHeight : scaledLineHeight
        let tracking = (style == .tabBar) ? base.tracking : scaledTracking

        let lineSpacing = max(0, lineHeight - size)

        return content
            .font(.app(style, size: size))
            .tracking(tracking)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(multilineAlignment)
    }
}
