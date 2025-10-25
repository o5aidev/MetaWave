//
//  Vaulting.swift
//  MetaWave
//
//  Miyabi仕様: E2E暗号化プロトコル
//

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

/// ストレージ操作プロトコル
protocol StorageProtocol {
    /// 暗号化して保存
    func save<T: Codable>(_ object: T, key: String) throws
    
    /// 復号化して読み込み
    func load<T: Codable>(_ type: T.Type, key: String) throws -> T?
    
    /// 削除
    func delete(key: String) throws
}
