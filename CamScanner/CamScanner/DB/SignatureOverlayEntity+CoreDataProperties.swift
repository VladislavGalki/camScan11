import Foundation
import CoreData

extension SignatureOverlayEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SignatureOverlayEntity> {
        NSFetchRequest<SignatureOverlayEntity>(entityName: "SignatureOverlayEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var pageIndex: Int16
    @NSManaged public var signatureEntityID: UUID
    @NSManaged public var centerX: Double
    @NSManaged public var centerY: Double
    @NSManaged public var width: Double
    @NSManaged public var height: Double
    @NSManaged public var rotation: Double
    @NSManaged public var colorHex: String
    @NSManaged public var thickness: Double
    @NSManaged public var opacity: Double
    @NSManaged public var imagePath: String
    @NSManaged public var aspectRatio: Double
    @NSManaged public var strokeData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var document: DocumentEntity?
}
