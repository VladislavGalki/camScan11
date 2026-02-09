import SwiftUI

// MARK: - Public API

enum AppColor: Hashable {
    case background(Background)
    case text(Text)
    case elements(Elements)
    case border(Border)
    case divider(Divider)

    enum Background: Hashable {
        case main
        case surface
        case accent
        case accentDisabled
        case accentSubtle
        case control
        case immersive
        case controlImmersive
        case hint
        case hintLight
        case detectionFrame
    }

    enum Text: Hashable {
        case primary
        case secondary
        case disabled
        case accent
        case accentDisabled
        case onAccent
        case onAccentDisabled
        case navigationDefault
        case navigationActive
        case onImmersive
        case onImmersiveMuted
        case onHint
        case distructive
    }

    enum Elements: Hashable {
        case primary
        case secondary
        case disabled
        case accent
        case accentDisabled
        case onAccent
        case onAccentDisabled
        case navigationDefault
        case navigationActive
        case onImmersive
    }

    enum Border: Hashable {
        case primary
        case primaryImmersive
        case hint
        case hintNeutral
        case detectionFrame
    }
    
    enum Divider: Hashable {
        case `default`
    }
}

extension Color {
    static func app(_ token: AppColor) -> Color { token.color }
}

extension ShapeStyle where Self == Color {
    static func app(_ token: AppColor) -> Color { token.color }
}

// MARK: - Mapping (values from Tokens.json / Mode 1)

private extension AppColor {
    var color: Color {
        switch self {

        // Backgrounds
        case .background(.main):            return .sRGB01(0.96862745, 0.96862745, 0.96862745, 1) // Bg/main
        case .background(.surface):         return .sRGB01(1, 1, 1, 1)                             // Bg/surface
        case .background(.accent):          return .sRGB01(0, 0.53333336, 1, 1)                     // Bg/accent
        case .background(.accentDisabled):  return .sRGB01(0.61960787, 0.73725492, 1, 1)            // Bg/accent-disabled
        case .background(.accentSubtle):    return .sRGB01(0.92549020, 0.94509804, 1, 1)            // Bg/accent-subtle
        case .background(.control):         return .sRGB01(0.93725491, 0.93725491, 0.93725491, 1)   // Bg/control
        case .background(.immersive):       return .sRGB01(0, 0, 0, 1)                               // Bg/immersive
        case .background(.controlImmersive):return .sRGB01(0.09019608, 0.09019608, 0.09019608, 1)   // Bg/control-immersive
        case .background(.hint):            return .sRGB01(0, 0.53333336, 1, 0.6)                    // Bg/hint
        case .background(.hintLight):       return .sRGB01(1, 1, 1, 0.2)
        case .background(.detectionFrame):  return .sRGB01(0, 0.53333336, 1, 0.1)                    // Bg/detection frame

        // Text
        case .text(.primary):           return .sRGB01(0, 0, 0, 1)                                   // Text/primary
        case .text(.secondary):         return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)        // Text/secondary
        case .text(.disabled):          return .sRGB01(0.63921571, 0.63921571, 0.63921571, 1)        // Text/disabled
        case .text(.accent):            return .sRGB01(0, 0.53333336, 1, 1)                           // Text/accent
        case .text(.accentDisabled):    return .sRGB01(0.85098040, 0.85098040, 0.85098040, 1)        // Text/accent-disabled
        case .text(.onAccent):          return .sRGB01(1, 1, 1, 1)                                   // Text/on accent
        case .text(.onAccentDisabled):  return .sRGB01(0.80784315, 0.86274511, 1, 1)                 // Text/on accent-disabled
        case .text(.navigationDefault): return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)        // Text/navigation-default
        case .text(.navigationActive):  return .sRGB01(0, 0.53333336, 1, 1)                           // Text/navigation-active
        case .text(.onImmersive):       return .sRGB01(1, 1, 1, 1)                                   // Text/on immersive
        case .text(.onImmersiveMuted):  return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)        // Text/on immersive-muted
        case .text(.onHint):            return .sRGB01(1, 1, 1, 1)                                   // Text/on hint
        case .text(.distructive):       return .sRGB01(1, 0.220, 0.235, 1)

        // Elements
        case .elements(.primary):           return .sRGB01(0, 0, 0, 1)                                // Elements/primary
        case .elements(.secondary):         return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)     // Elements/secondary
        case .elements(.disabled):          return .sRGB01(0.63921571, 0.63921571, 0.63921571, 1)     // Elements/disabled
        case .elements(.accent):            return .sRGB01(0, 0.53333336, 1, 1)                        // Elements/accent
        case .elements(.accentDisabled):    return .sRGB01(0.85098040, 0.85098040, 0.85098040, 1)     // Elements/accent-disabled
        case .elements(.onAccent):          return .sRGB01(1, 1, 1, 1)                                // Elements/on accent
        case .elements(.onAccentDisabled):  return .sRGB01(0.80784315, 0.86274511, 1, 1)              // Elements/on accent-disabled
        case .elements(.navigationDefault): return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)     // Elements/navigation-default
        case .elements(.navigationActive):  return .sRGB01(0, 0.53333336, 1, 1)                        // Elements/navigation-active
        case .elements(.onImmersive):       return .sRGB01(1, 1, 1, 1)                                // Elements/on immersive

        // Borders
        case .border(.primary):          return .sRGB01(0.93725491, 0.93725491, 0.93725491, 1)        // Borders/primary
        case .border(.primaryImmersive): return .sRGB01(0.17647059, 0.17647059, 0.17647059, 1)        // Borders/primary-immersive
        case .border(.hint):             return .sRGB01(0, 0.53333336, 1, 0.2)                         // Borders/hint
        case .border(.hintNeutral):      return .sRGB01(1, 1, 1, 0.1)
        case .border(.detectionFrame):   return .sRGB01(0, 0.53333336, 1, 1)                           // Borders/detection frame
            
        // Dividers
        case .divider(.default):        return .sRGB01(0.937, 0.937, 0.937, 1)
        }
    }
}

// MARK: - Helpers

private extension Color {
    /// r,g,b,a в диапазоне 0...1 (как в твоих токенах)
    static func sRGB01(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Aliases (Sugar API)

extension ShapeStyle where Self == Color {

    // Background
    static func bg(_ token: AppColor.Background) -> Color {
        .app(.background(token))
    }

    // Text
    static func text(_ token: AppColor.Text) -> Color {
        .app(.text(token))
    }

    // Elements
    static func elements(_ token: AppColor.Elements) -> Color {
        .app(.elements(token))
    }

    // Border
    static func border(_ token: AppColor.Border) -> Color {
        .app(.border(token))
    }
    
    // Divider
    static func divider(_ token: AppColor.Divider) -> Color {
        .app(.divider(token))
    }
}
