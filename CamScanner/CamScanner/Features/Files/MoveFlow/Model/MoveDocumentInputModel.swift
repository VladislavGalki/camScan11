import Foundation

struct MoveDocumentInputModel {
    let viewMode: FilesViewMode
    let folderId: UUID?
    let documentIDs: [UUID]
}
