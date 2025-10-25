import Foundation
import CryptoKit

/// 暗号化されたデータブロブ
struct EncryptedBlob {
    let ciphertext: Data
    let nonce: Data
    let tag: Data
}

/// 暗号化・復号化プロトコル
protocol Vaulting {
    /// 対称鍵を生成または読み込み
    func loadOrCreateSymmetricKey() throws -> SymmetricKey
    
    /// データを暗号化
    func encrypt(_ data: Data) throws -> EncryptedBlob
    
    /// データを復号化
    func decrypt(_ blob: EncryptedBlob) throws -> Data
}

/// Miyabi仕様: E2E暗号化Vault実装
final class Vault: Vaulting {
    static let shared = Vault()
    
    private static let keyName = "app.masterKey"
    private var symmetricKey: SymmetricKey?
    
    private init() {}
    
    // MARK: - Vaulting Protocol
    
    func loadOrCreateSymmetricKey() throws -> SymmetricKey {
        if let key = symmetricKey {
            return key
        }
        
        if let keyData = try Keychain.load(for: Self.keyName) {
            // 既存の鍵を復元
            symmetricKey = SymmetricKey(data: keyData)
        } else {
            // 新しい鍵を生成
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try Keychain.save(keyData, for: Self.keyName)
            symmetricKey = newKey
        }
        
        return symmetricKey!
    }
    
    func encrypt(_ data: Data) throws -> EncryptedBlob {
        let key = try loadOrCreateSymmetricKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        return EncryptedBlob(
            ciphertext: sealedBox.ciphertext,
            nonce: Data(sealedBox.nonce),
            tag: sealedBox.tag
        )
    }
    
    func decrypt(_ blob: EncryptedBlob) throws -> Data {
        let key = try loadOrCreateSymmetricKey()
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: blob.nonce),
            ciphertext: blob.ciphertext,
            tag: blob.tag
        )
        
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Legacy Support
    
    /// 既存コードとの互換性のため
    static func generateOrLoadVaultKey() throws -> Data {
        let key = try Vault.shared.loadOrCreateSymmetricKey()
        return key.withUnsafeBytes { Data($0) }
    }
}
