import Foundation

struct ScanInputModel {
    let existingDocumentID: UUID?

    init(existingDocumentID: UUID? = nil) {
        self.existingDocumentID = existingDocumentID
    }
}
