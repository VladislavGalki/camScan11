import Foundation

struct ScanPreviewInputModel {
    let pages: [CapturedFrame]
    let previewMode: PreviewMode
    let selectedFilterKey: String?
    
    init(pages: [CapturedFrame], previewMode: PreviewMode, selectedFilterKey: String? = nil) {
        self.pages = pages
        self.previewMode = previewMode
        self.selectedFilterKey = selectedFilterKey
    }
}
