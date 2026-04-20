import Foundation
import CryptoKit

final class PasswordCryptoService {
    init() {}

    func generateSalt() -> Data {
        var data = Data(count: 16)
        _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        return data
    }

    func hash(pin: String, salt: Data) -> Data {
        let data = Data(pin.utf8) + salt
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }

    func verify(pin: String, salt: Data, hash: Data) -> Bool {
        return self.hash(pin: pin, salt: salt) == hash
    }
}
