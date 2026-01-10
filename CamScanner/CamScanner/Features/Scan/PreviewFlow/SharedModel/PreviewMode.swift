import Foundation

enum PreviewMode: Equatable {
    case newFromCamera
    case existing(docID: UUID)
}
