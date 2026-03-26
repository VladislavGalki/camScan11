import Foundation
import CoreData

extension WatermarkOverlayEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WatermarkOverlayEntity> {
        NSFetchRequest<WatermarkOverlayEntity>(entityName: "WatermarkOverlayEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var pageIndex: Int16
    @NSManaged public var text: String
    @NSManaged public var centerX: Double
    @NSManaged public var centerY: Double
    @NSManaged public var width: Double
    @NSManaged public var height: Double
    @NSManaged public var rotation: Double
    @NSManaged public var isTile: Bool
    @NSManaged public var opacity: Double
    @NSManaged public var fontSize: Double
    @NSManaged public var textColorHex: String
    @NSManaged public var alignmentRaw: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var document: DocumentEntity?
}
