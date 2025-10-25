//
//  VaultTests.swift
//  MetaWave
//
//  Miyabi仕様: Vault暗号化テスト
//

import XCTest
import CryptoKit
@testable import MetaWave

final class VaultTests: XCTestCase {
    
    var vault: Vault!
    
    override func setUp() {
        super.setUp()
        vault = Vault.shared
    }
    
    override func tearDown() {
        vault = nil
        super.tearDown()
    }
    
    func testSymmetricKeyGeneration() throws {
        // 鍵生成テスト
        let key1 = try vault.loadOrCreateSymmetricKey()
        let key2 = try vault.loadOrCreateSymmetricKey()
        
        // 同じ鍵が返されることを確認
        XCTAssertEqual(key1.withUnsafeBytes { Data($0) }, key2.withUnsafeBytes { Data($0) })
    }
    
    func testEncryptionDecryption() throws {
        let testData = "Hello, MetaWave!".data(using: .utf8)!
        
        // 暗号化
        let encryptedBlob = try vault.encrypt(testData)
        
        // 復号化
        let decryptedData = try vault.decrypt(encryptedBlob)
        
        // 元のデータと一致することを確認
        XCTAssertEqual(testData, decryptedData)
    }
    
    func testEncryptionIntegrity() throws {
        let testData = "Test data for integrity check".data(using: .utf8)!
        
        // 暗号化
        let encryptedBlob = try vault.encrypt(testData)
        
        // タグが存在することを確認
        XCTAssertFalse(encryptedBlob.tag.isEmpty)
        XCTAssertFalse(encryptedBlob.nonce.isEmpty)
        XCTAssertFalse(encryptedBlob.ciphertext.isEmpty)
    }
    
    func testDifferentDataProducesDifferentCiphertext() throws {
        let data1 = "First message".data(using: .utf8)!
        let data2 = "Second message".data(using: .utf8)!
        
        let blob1 = try vault.encrypt(data1)
        let blob2 = try vault.encrypt(data2)
        
        // 異なるデータは異なる暗号文を生成することを確認
        XCTAssertNotEqual(blob1.ciphertext, blob2.ciphertext)
    }
}
