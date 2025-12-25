import Foundation

enum ScanTopPanel: Equatable {
    case none
    case flash
    case quality
    case filters
    case settings
}

enum CaptureMode: String, CaseIterable, Identifiable {
    case single = "Один"
    case group = "Группа"
    var id: String { rawValue }
}

enum FlashMode: String, CaseIterable, Identifiable {
    case off = "Выкл."
    case on = "Вкл."
    case auto = "Авто"
    case torch = "Постоянная"

    var id: String { rawValue }
}

enum QualityPreset: String, CaseIterable, Identifiable {
    case hd = "HD"
    case large = "Большое"
    case standard = "Стандартное"
    case small = "Меньше"

    var id: String { rawValue }

    /// целевые размеры (downscale после capture)
    var maxDimension: CGFloat {
        switch self {
        case .hd: return 4032
        case .large: return 3264
        case .standard: return 2880
        case .small: return 1920
        }
    }

    var subtitle: String {
        switch self {
        case .hd: return "4032×3024"
        case .large: return "3264×2488"
        case .standard: return "2880×2156"
        case .small: return "1920×1440"
        }
    }
}

enum ScanFilter: String, CaseIterable, Identifiable {
    case original = "Оригинал"
    case eco = "Эко"
    case gray = "Шкала серого"
    case bw = "Ч/Б"
    case cancelShadows = "Без теней"

    var id: String { rawValue }
}

struct ScanSettingsKeys {
    static let autoShoot = "scan.autoShoot"
    static let grid = "scan.grid"
    static let textOrientationRotate = "scan.textRotate"
    static let volumeShutter = "scan.volumeShutter"
    static let autoCrop = "scan.autoCrop"

    static let flashMode = "scan.flashMode"
    static let quality = "scan.quality"
    static let filter = "scan.filter"
    static let captureMode = "scan.captureMode"
}
