import UIKit
import SwiftUI

public extension Color {
    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
    
    init?(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
    
    init?(rgbaHex: String) {
        let hex = rgbaHex
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }

        switch hex.count {
        case 6:
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >> 8) & 0xFF) / 255
            let b = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, opacity: 1)

        case 8:
            let r = Double((value >> 24) & 0xFF) / 255
            let g = Double((value >> 16) & 0xFF) / 255
            let b = Double((value >> 8) & 0xFF) / 255
            let a = Double(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, opacity: a)

        default:
            return nil
        }
    }

    func toRGBAHex() -> String? {
        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

        return String(
            format: "#%02X%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255)),
            Int(round(a * 255))
        )
    }
}

extension String {
    var withHashPrefixRGBA: String {
        let cleaned = self.replacingOccurrences(of: "#", with: "").uppercased()

        switch cleaned.count {
        case 6:
            return "#\(cleaned)FF"
        case 8:
            return "#\(cleaned)"
        default:
            return "#020202FF"
        }
    }
}

extension UIColor {
    convenience init?(rgbaHex: String) {
        let hex = rgbaHex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }

        switch hex.count {
        case 6:
            let r = CGFloat((value >> 16) & 0xFF) / 255
            let g = CGFloat((value >> 8) & 0xFF) / 255
            let b = CGFloat(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, alpha: 1)

        case 8:
            let r = CGFloat((value >> 24) & 0xFF) / 255
            let g = CGFloat((value >> 16) & 0xFF) / 255
            let b = CGFloat((value >> 8) & 0xFF) / 255
            let a = CGFloat(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, alpha: a)

        default:
            return nil
        }
    }
}
