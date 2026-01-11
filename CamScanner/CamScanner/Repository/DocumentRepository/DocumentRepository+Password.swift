import Foundation
import CoreData

extension DocumentRepository {

    func setPassword(docID: UUID, password: String) throws {
        guard let doc = try fetchDocument(id: docID) else { return }

        let hasher = PasswordHasher()
        let salt = hasher.makeSalt()
        let hash = hasher.hash(password: password, salt: salt)

        doc.isLocked = true
        doc.passwordSalt = salt
        doc.passwordHash = hash

        try context.save()
    }

    func verifyPassword(docID: UUID, password: String) throws -> Bool {
        guard let doc = try fetchDocument(id: docID) else { return false }
        guard doc.isLocked else { return true }

        guard
            let salt = doc.passwordSalt,
            let hash = doc.passwordHash
        else { return false }

        return PasswordHasher().verify(
            password: password,
            salt: salt,
            expectedHash: hash
        )
    }

    func removePassword(docID: UUID, password: String) throws {
        guard let doc = try fetchDocument(id: docID) else { return }

        guard doc.isLocked else { return }

        guard
            let salt = doc.passwordSalt,
            let hash = doc.passwordHash
        else {
            return
        }

        let isValid = PasswordHasher().verify(
            password: password,
            salt: salt,
            expectedHash: hash
        )

        guard isValid else {
            return
        }

        doc.isLocked = false
        doc.passwordSalt = nil
        doc.passwordHash = nil

        try context.save()
    }

    private func fetchDocument(id: UUID) throws -> DocumentEntity? {
        let req: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try context.fetch(req).first
    }
}
