import Foundation
import UIKit

enum DocumentPreviewKind: Equatable {
    case scan
    case id(idTypeRaw: String, title: String)
}

struct DocumentPreviewInputModel {
    let kind: DocumentPreviewKind
    let pages: [CapturedFrame]
    let previewMode: PreviewMode
    let rememberedFilterKey: String?

    init(
        kind: DocumentPreviewKind,
        pages: [CapturedFrame],
        previewMode: PreviewMode,
        rememberedFilterKey: String? = nil
    ) {
        self.kind = kind
        self.pages = pages
        self.previewMode = previewMode
        self.rememberedFilterKey = rememberedFilterKey
    }

    static func scan(
        pages: [CapturedFrame],
        previewMode: PreviewMode,
        rememberedFilterKey: String? = nil
    ) -> DocumentPreviewInputModel {
        .init(
            kind: .scan,
            pages: pages,
            previewMode: previewMode,
            rememberedFilterKey: rememberedFilterKey
        )
    }

    static func id(
        result: IdCaptureResult,
        previewMode: PreviewMode,
        rememberedFilterKey: String? = nil
    ) -> DocumentPreviewInputModel {
        var pages: [CapturedFrame] = []
        pages.append(result.front)
        if result.requiresBackSide, let back = result.back {
            pages.append(back)
        }
        
        return .id(result: .init(type: .documents), previewMode: previewMode)

//        return .init(
//            kind: .id(idTypeRaw: result.idType.id, title: result.idType.title),
//            pages: pages,
//            previewMode: previewMode,
//            rememberedFilterKey: rememberedFilterKey
//        )
    }
}
