import Foundation

struct Vault {
    private static let keyName = "app.masterKey"

    static func generateOrLoadVaultKey() throws -> Data {
        if let existing = try Keychain.load(for: keyName) {
            return existing
        } else {
            let newKey = UUID().uuidString.data(using: .utf8)!
            try Keychain.save(newKey, for: keyName)
            return newKey
        }
    }
}
