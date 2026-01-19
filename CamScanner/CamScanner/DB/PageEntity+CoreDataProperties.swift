//
//  PageEntity+CoreDataProperties.swift
//  CamScanner
//
//  Created by Владислав Галкин on 08.01.2026.
//
//

import Foundation
import CoreData


extension PageEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PageEntity> {
        return NSFetchRequest<PageEntity>(entityName: "PageEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var imagePath: String?
    @NSManaged public var index: Int16
    @NSManaged public var quadData: Data?
    @NSManaged public var drawingData: Data?
    @NSManaged public var drawingBasePath: String?
    @NSManaged public var filter: String?
    @NSManaged public var document: DocumentEntity?
    @NSManaged public var originalPath: String?

}

extension PageEntity : Identifiable {

}
