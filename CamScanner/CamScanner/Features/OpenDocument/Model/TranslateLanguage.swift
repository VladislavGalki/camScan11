import SwiftUI

enum TranslateLanguage: String, CaseIterable, Identifiable {
    case arabic
    case chinese
    case czech
    case dutch
    case english
    case german
    case greek
    case hebrew
    case hindi
    case hungarian
    case italian
    case japanese
    case korean
    case polish
    case portuguese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arabic: return "Arabic"
        case .chinese: return "Chinese"
        case .czech: return "Czech"
        case .dutch: return "Dutch"
        case .english: return "English"
        case .german: return "German"
        case .greek: return "Greek"
        case .hebrew: return "Hebrew"
        case .hindi: return "Hindi"
        case .hungarian: return "Hungarian"
        case .italian: return "Italian"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .polish: return "Polish"
        case .portuguese: return "Portuguese"
        }
    }

    var localeCode: String {
        switch self {
        case .arabic: return "ar"
        case .chinese: return "zh-CN"
        case .czech: return "cs"
        case .dutch: return "nl"
        case .english: return "en"
        case .german: return "de"
        case .greek: return "el"
        case .hebrew: return "he"
        case .hindi: return "hi"
        case .hungarian: return "hu"
        case .italian: return "it"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .polish: return "pl"
        case .portuguese: return "pt"
        }
    }

    var icon: AppIcon {
        switch self {
        case .arabic: return .arabic
        case .chinese: return .china
        case .czech: return .czech
        case .dutch: return .dutch
        case .english: return .english
        case .german: return .germany
        case .greek: return .greek
        case .hebrew: return .hebrew
        case .hindi: return .hindi
        case .hungarian: return .hungarian
        case .italian: return .inatian
        case .japanese: return .japanese
        case .korean: return .korean
        case .polish: return .polish
        case .portuguese: return .portugal
        }
    }

    var ocrLanguagePrefix: String {
        switch self {
        case .arabic: return "ar"
        case .chinese: return "zh"
        case .czech: return "cs"
        case .dutch: return "nl"
        case .english: return "en"
        case .german: return "de"
        case .greek: return "el"
        case .hebrew: return "he"
        case .hindi: return "hi"
        case .hungarian: return "hu"
        case .italian: return "it"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .polish: return "pl"
        case .portuguese: return "pt"
        }
    }

    static func fromOCRLanguage(_ code: String) -> TranslateLanguage? {
        let prefix = code.components(separatedBy: "-").first ?? code
        return allCases.first { $0.ocrLanguagePrefix == prefix.lowercased() }
    }
}
