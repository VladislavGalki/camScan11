import Foundation

struct IdPreviewInputModel {
    let result: IdCaptureResult
    let selectedFilterKey: String?
    let previewMode: PreviewMode
    
    init(result: IdCaptureResult, previewMode: PreviewMode, selectedFilterKey: String? = nil) {
        self.result = result
        self.previewMode = previewMode
        self.selectedFilterKey = selectedFilterKey
    }
}
