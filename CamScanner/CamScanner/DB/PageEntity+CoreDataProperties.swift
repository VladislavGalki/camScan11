import Foundation
import CoreData

extension PageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PageEntity> {
        NSFetchRequest<PageEntity>(entityName: "PageEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var index: Int16

    @NSManaged public var imagePath: String?
    @NSManaged public var originalPath: String?
    @NSManaged public var drawingBasePath: String?

    @NSManaged public var quadData: Data?
    @NSManaged public var drawingData: Data?

    @NSManaged public var filterTypeRaw: String?
    @NSManaged public var filterAdjustment: Double
    @NSManaged public var rotationAngle: Double

    @NSManaged public var sourceDocumentTypeRaw: String
    
    @NSManaged public var document: DocumentEntity?
}

extension PageEntity: Identifiable {}
