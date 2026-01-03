import UIKit

enum IdCaptureSide: Equatable {
    case front
    case back
}

struct CapturedFrame: Equatable {
    var preview: UIImage? = nil
    var original: UIImage? = nil
    /// Для ID мы сейчас режем по рамке, quad может быть nil.
    /// Но оставляем поле, чтобы в будущем легко добавить/хранить quad (например для ручной обрезки).
    var quad: Quadrilateral? = nil

    var isReady: Bool { preview != nil && original != nil }
}

struct IdCaptureResult: Equatable {
    var idType: IdDocumentTypeEnum
    var front: CapturedFrame = .init()
    var back: CapturedFrame? = nil

    var requiresBackSide: Bool { idType.requiresBackSide }

    var isReadyForPreview: Bool {
        if requiresBackSide {
            return front.isReady && (back?.isReady ?? false)
        } else {
            return front.isReady
        }
    }
}

extension IdDocumentTypeEnum {
    /// ✅ по твоему требованию: identification/driverLicense/bankCard -> 2 фото
    var requiresBackSide: Bool {
        switch self {
        case .identification, .driverLicense, .bankCard:
            return true
        case .general, .passport:
            return false
        }
    }
}
