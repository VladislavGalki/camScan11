import SwiftUI

enum AppColor: Hashable {
    case background(Background)
    case text(Text)
    case elements(Elements)
    case border(Border)
    case divider(Divider)

    // MARK: Background
    
    enum Background: Hashable {
        
        case main
        case surface
        
        case accent
        case accentDisabled
        case accentSubtle
        
        case control
        case controlOnMain
        case controlOnSurface
        case controlImmersive
        
        case controlContainerTranslucent
        case controlOnContainer
        
        case immersive
        
        case hintBlue
        case hintGreen
        case hintOrange
        case hintLight
        
        case detectionFrame
        
        case overlay
        
        case success
        case warning
        case destructive
    }

    // MARK: Text
    
    enum Text: Hashable {
        
        case primary
        case secondary
        case tertiary
        case disabled
        
        case accent
        case accentDisabled
        
        case link
        
        case onAccent
        case onAccentDisabled
        
        case onSuccess
        
        case onImmersive
        case onImmersiveMuted
        
        case onHint
        
        case onOverlay
        
        case destructive
        
        case navigationDefault
        case navigationActive
    }

    // MARK: Elements
    
    enum Elements: Hashable {
        
        case primary
        case secondary
        case tertiary
        case disabled
        
        case accent
        case accentDisabled
        case warning
        
        case destructive
        
        case onAccent
        case onAccentDisabled
        
        case onSuccess
        
        case onImmersive
        
        case onOverlayPrimary
        case onOverlayDisabled
        
        case navigationDefault
        case navigationActive
    }

    // MARK: Border
    
    enum Border: Hashable {
        
        case primary
        case primaryImmersive
        
        case accent
        case accentSubtle
        
        case onSuccess
        
        case hintBlue
        case hintGreen
        case hintOrange
        case hintNeutral
        
        case detectionFrame
    }

    // MARK: Divider
    
    enum Divider: Hashable {
        case `default`
    }
}

// MARK: - Public accessors

extension Color {
    
    static func app(_ token: AppColor) -> Color {
        token.color
    }
}

extension ShapeStyle where Self == Color {
    
    static func app(_ token: AppColor) -> Color {
        token.color
    }
}

// MARK: - Mapping

private extension AppColor {
    
    var color: Color {
        
        switch self {
            
        // MARK: Background
        
        case .background(.main):
            return .sRGB01(0.96862745, 0.96862745, 0.96862745, 1)
            
        case .background(.surface):
            return .sRGB01(1, 1, 1, 1)
            
        case .background(.accent):
            return .sRGB01(0, 0.53333336, 1, 1)
            
        case .background(.accentDisabled):
            return .sRGB01(0.61960787, 0.73725492, 1, 1)
            
        case .background(.accentSubtle):
            return .sRGB01(0.9254902, 0.94509804, 1, 1)
            
        case .background(.control):
            return .sRGB01(0.9372549, 0.9372549, 0.9372549, 1)
            
        case .background(.controlOnMain):
            return .sRGB01(0.90196079, 0.90196079, 0.90196079, 1)
            
        case .background(.controlOnSurface):
            return .sRGB01(0.9372549, 0.9372549, 0.9372549, 1)
            
        case .background(.controlImmersive):
            return .sRGB01(0.09019608, 0.09019608, 0.09019608, 1)
            
        case .background(.controlContainerTranslucent):
            return .sRGB01(0, 0, 0, 0.6)
            
        case .background(.controlOnContainer):
            return .sRGB01(0.17647059, 0.17647059, 0.17647059, 1)
            
        case .background(.immersive):
            return .sRGB01(0, 0, 0, 1)
            
        case .background(.hintBlue):
            return .sRGB01(0, 0.53333336, 1, 0.6)
            
        case .background(.hintGreen):
            return .sRGB01(0.20392157, 0.78039217, 0.34901962, 0.6)
            
        case .background(.hintOrange):
            return .sRGB01(1, 0.5529412, 0.15686275, 0.6)
            
        case .background(.hintLight):
            return .sRGB01(1, 1, 1, 0.2)
            
        case .background(.detectionFrame):
            return .sRGB01(0, 0.53333336, 1, 0.1)
            
        case .background(.overlay):
            return .sRGB01(0, 0, 0, 0.6)
            
        case .background(.success):
            return .sRGB01(0.20392157, 0.78039217, 0.34901962, 1)
            
        case .background(.warning):
            return .sRGB01(1, 0.5529412, 0.15686275, 1)
            
        case .background(.destructive):
            return .sRGB01(1, 0.21960784, 0.23529412, 1)
            
            
        // MARK: Text
        
        case .text(.primary):
            return .sRGB01(0, 0, 0, 1)
            
        case .text(.secondary):
            return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)
            
        case .text(.tertiary):
            return .sRGB01(0.6392157, 0.6392157, 0.6392157, 1)
            
        case .text(.disabled):
            return .sRGB01(0.8509804, 0.8509804, 0.8509804, 1)
            
        case .text(.accent):
            return .sRGB01(0, 0.53333336, 1, 1)
            
        case .text(.accentDisabled):
            return .sRGB01(0.8509804, 0.8509804, 0.8509804, 1)
            
        case .text(.link):
            return .sRGB01(0, 0.53333336, 1, 1)
            
        case .text(.onAccent):
            return .sRGB01(1, 1, 1, 1)
            
        case .text(.onAccentDisabled):
            return .sRGB01(0.80784315, 0.86274511, 1, 1)
            
        case .text(.onSuccess):
            return .sRGB01(0.784, 0.996, 0.816, 1)
            
        case .text(.onImmersive):
            return .sRGB01(1, 1, 1, 1)
            
        case .text(.onImmersiveMuted):
            return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)
            
        case .text(.onHint):
            return .sRGB01(1, 1, 1, 1)
            
        case .text(.onOverlay):
            return .sRGB01(1, 1, 1, 1)
            
        case .text(.destructive):
            return .sRGB01(1, 0.21960784, 0.23529412, 1)
            
        case .text(.navigationDefault):
            return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)
            
        case .text(.navigationActive):
            return .sRGB01(0, 0.53333336, 1, 1)
            
            
        // MARK: Elements
        
        case .elements(.primary):
            return .sRGB01(0, 0, 0, 1)
            
        case .elements(.secondary):
            return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)
            
        case .elements(.tertiary):
            return .sRGB01(0.6392157, 0.6392157, 0.6392157, 1)
            
        case .elements(.disabled):
            return .sRGB01(0.8509804, 0.8509804, 0.8509804, 1)
            
        case .elements(.accent):
            return .sRGB01(0, 0.53333336, 1, 1)
            
        case .elements(.accentDisabled):
            return .sRGB01(0.8509804, 0.8509804, 0.8509804, 1)
            
        case .elements(.warning):
            return .sRGB01(1.000, 0.553, 0.157, 1)
            
        case .elements(.destructive):
            return .sRGB01(1, 0.21960784, 0.23529412, 1)
            
        case .elements(.onAccent):
            return .sRGB01(1, 1, 1, 1)
            
        case .elements(.onAccentDisabled):
            return .sRGB01(0.80784315, 0.86274511, 1, 1)
            
        case .elements(.onSuccess):
            return .sRGB01(0.784, 0.996, 0.816, 1)
            
        case .elements(.onImmersive):
            return .sRGB01(1, 1, 1, 1)
            
        case .elements(.onOverlayPrimary):
            return .sRGB01(1, 1, 1, 1)
            
        case .elements(.onOverlayDisabled):
            return .sRGB01(1, 1, 1, 0.3)
            
        case .elements(.navigationDefault):
            return .sRGB01(0.40392157, 0.40392157, 0.40392157, 1)
            
        case .elements(.navigationActive):
            return .sRGB01(0, 0.53333336, 1, 1)
            
            
        // MARK: Border
        
        case .border(.primary):
            return .sRGB01(0.9372549, 0.9372549, 0.9372549, 1)
            
        case .border(.primaryImmersive):
            return .sRGB01(0.17647059, 0.17647059, 0.17647059, 1)
            
        case .border(.accent):
            return .sRGB01(0, 0.53333336, 1, 1)
            
        case .border(.accentSubtle):
            return .sRGB01(0.80784315, 0.86274511, 1, 1)
            
        case .border(.onSuccess):
            return .sRGB01(0.235, 0.882, 0.400, 1)
            
        case .border(.hintBlue):
            return .sRGB01(0, 0.53333336, 1, 0.3)
            
        case .border(.hintGreen):
            return .sRGB01(0.20392157, 0.78039217, 0.34901962, 0.3)
            
        case .border(.hintOrange):
            return .sRGB01(1, 0.5529412, 0.15686275, 0.1)
            
        case .border(.hintNeutral):
            return .sRGB01(1, 1, 1, 0.1)
            
        case .border(.detectionFrame):
            return .sRGB01(0, 0.53333336, 1, 1)
            
            
        // MARK: Divider
        
        case .divider(.default):
            return .sRGB01(0.9372549, 0.9372549, 0.9372549, 1)
        }
    }
}

// MARK: - Helpers

private extension Color {
    
    static func sRGB01(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Sugar API

extension ShapeStyle where Self == Color {
    
    static func bg(_ token: AppColor.Background) -> Color {
        .app(.background(token))
    }

    static func text(_ token: AppColor.Text) -> Color {
        .app(.text(token))
    }

    static func elements(_ token: AppColor.Elements) -> Color {
        .app(.elements(token))
    }

    static func border(_ token: AppColor.Border) -> Color {
        .app(.border(token))
    }

    static func divider(_ token: AppColor.Divider) -> Color {
        .app(.divider(token))
    }
}
