import Foundation
import CoreData

extension SignatureEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SignatureEntity> {
        NSFetchRequest<SignatureEntity>(entityName: "SignatureEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged public var imagePath: String
    @NSManaged public var createdAt: Date
}
