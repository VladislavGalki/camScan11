import Foundation
import CoreData

extension FolderEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FolderEntity> {
        NSFetchRequest<FolderEntity>(entityName: "FolderEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?

    @NSManaged public var documents: NSSet?
}

// MARK: Generated accessors for documents
extension FolderEntity {

    @objc(addDocumentsObject:)
    @NSManaged public func addToDocuments(_ value: DocumentEntity)

    @objc(removeDocumentsObject:)
    @NSManaged public func removeFromDocuments(_ value: DocumentEntity)

    @objc(addDocuments:)
    @NSManaged public func addToDocuments(_ values: NSSet)

    @objc(removeDocuments:)
    @NSManaged public func removeFromDocuments(_ values: NSSet)
}

extension FolderEntity: Identifiable {}
