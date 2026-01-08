//
//  DocumentEntity+CoreDataProperties.swift
//  CamScanner
//
//  Created by Владислав Галкин on 08.01.2026.
//
//

import Foundation
import CoreData


extension DocumentEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DocumentEntity> {
        return NSFetchRequest<DocumentEntity>(entityName: "DocumentEntity")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var pageCount: Int16
    @NSManaged public var rememberedFilter: String?
    @NSManaged public var kind: String?
    @NSManaged public var idType: String?
    @NSManaged public var pages: NSSet?

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

extension DocumentEntity : Identifiable {

}
