import Foundation
import CommonCrypto

final class PasswordHasher {

    func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    func hash(password: String, salt: Data) -> Data? {
        let passwordData = Data(password.utf8)
        var derivedKey = [UInt8](repeating: 0, count: 32)

        let result = salt.withUnsafeBytes { saltPtr in
            passwordData.withUnsafeBytes { passPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passPtr.bindMemory(to: Int8.self).baseAddress,
                    passwordData.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    150_000,
                    &derivedKey,
                    derivedKey.count
                )
            }
        }

        return result == kCCSuccess ? Data(derivedKey) : nil
    }

    func verify(password: String, salt: Data, expectedHash: Data) -> Bool {
        guard let newHash = hash(password: password, salt: salt) else { return false }
        return constantTimeCompare(newHash, expectedHash)
    }

    private func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }
}
