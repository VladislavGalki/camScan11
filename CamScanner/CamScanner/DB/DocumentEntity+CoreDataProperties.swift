import Foundation
import CoreData

extension DocumentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DocumentEntity> {
        NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var documentTypeRaw: String?
    @NSManaged public var pageCount: Int16
    @NSManaged public var isLocked: Bool
    @NSManaged public var passwordSalt: Data?
    @NSManaged public var passwordHash: Data?

    @NSManaged public var pages: NSSet?
    @NSManaged public var folder: FolderEntity?
}

// MARK: Generated accessors for pages
extension DocumentEntity {

    @objc(addPagesObject:)
    @NSManaged public func addToPages(_ value: PageEntity)

    @objc(removePagesObject:)
    @NSManaged public func removeFromPages(_ value: PageEntity)

    @objc(addPages:)
    @NSManaged public func addToPages(_ values: NSSet)

    @objc(removePages:)
    @NSManaged public func removeFromPages(_ values: NSSet)
}

extension DocumentEntity: Identifiable {}
