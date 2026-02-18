import Security
import Foundation

final class KeychainService {
    static let shared = KeychainService()

    func save<T: Codable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder().encode(value)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    func load<T: Codable>(_ type: T.Type, for key: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { return nil }

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }

        return try JSONDecoder().decode(type, from: data)
    }
}
