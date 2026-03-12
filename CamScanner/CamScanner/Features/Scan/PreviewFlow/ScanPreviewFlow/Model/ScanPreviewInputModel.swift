import Foundation

struct PreviewPageGroup: Identifiable, Equatable, Hashable {
    let id = UUID()
    let documentType: DocumentTypeEnum
    let frames: [CapturedFrame]
}

struct ScanPreviewInputModel: Equatable, Hashable {
    let pageGroups: [PreviewPageGroup]
}
