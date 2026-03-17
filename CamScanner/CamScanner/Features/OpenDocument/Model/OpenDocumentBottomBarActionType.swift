import Foundation

enum OpenDocumentBottomBarActionType: CaseIterable, Identifiable {
    case addPage
    case crop
    case rotate
    case addText
    case signature
    case erase
    case watermark
    case extract
    case translate
    case delete

    var id: Self { self }

    var title: String {
        switch self {
        case .addPage: "Add Page"
        case .crop: "Crop"
        case .rotate: "Rotate"
        case .addText: "Add text"
        case .signature: "Signature"
        case .erase: "Erase"
        case .watermark: "Watermark"
        case .extract: "Extract"
        case .translate: "Translate"
        case .delete: "Delete"
        }
    }

    var icon: AppIcon {
        switch self {
        case .addPage: .page_plus
        case .crop: .crop
        case .rotate: .rotate
        case .addText: .addText
        case .signature: .signature
        case .erase: .erase
        case .watermark: .watermark
        case .extract: .extract
        case .translate: .translate
        case .delete: .trash
        }
    }

    var isDestructive: Bool {
        switch self {
        case .delete:
            return true
        default:
            return false
        }
    }
}
