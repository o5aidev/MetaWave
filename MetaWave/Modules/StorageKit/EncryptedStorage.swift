//
//  EncryptedStorage.swift
//  MetaWave
//
//  Miyabi仕様: 暗号化ストレージ実装
//

import Foundation
import CoreData

/// 暗号化ストレージ実装
final class EncryptedStorage: StorageProtocol {
    private let vault: Vaulting
    private let userDefaults = UserDefaults.standard
    
    init(vault: Vaulting = Vault.shared) {
        self.vault = vault
    }
    
    func save<T: Codable>(_ object: T, key: String) throws {
        let data = try JSONEncoder().encode(object)
        let encryptedBlob = try vault.encrypt(data)
        
        // 暗号化されたデータをUserDefaultsに保存
        let storageData = try JSONEncoder().encode(encryptedBlob)
        userDefaults.set(storageData, forKey: key)
    }
    
    func load<T: Codable>(_ type: T.Type, key: String) throws -> T? {
        guard let storageData = userDefaults.data(forKey: key) else {
            return nil
        }
        
        let encryptedBlob = try JSONDecoder().decode(EncryptedBlob.self, from: storageData)
        let decryptedData = try vault.decrypt(encryptedBlob)
        
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    func delete(key: String) throws {
        userDefaults.removeObject(forKey: key)
    }
}

/// CoreData用暗号化ラッパー
final class EncryptedCoreDataStorage {
    private let vault: Vaulting
    private let context: NSManagedObjectContext
    
    init(vault: Vaulting = Vault.shared, context: NSManagedObjectContext) {
        self.vault = vault
        self.context = context
    }
    
    /// 暗号化してCoreDataに保存
    func saveEncrypted<T: Codable>(_ object: T, to entity: String, key: String) throws {
        let data = try JSONEncoder().encode(object)
        let encryptedBlob = try vault.encrypt(data)
        
        // CoreDataエンティティに保存
        let entityDescription = NSEntityDescription.entity(forEntityName: entity, in: context)!
        let managedObject = NSManagedObject(entity: entityDescription, insertInto: context)
        
        managedObject.setValue(encryptedBlob.ciphertext, forKey: "\(key)_ciphertext")
        managedObject.setValue(encryptedBlob.nonce, forKey: "\(key)_nonce")
        managedObject.setValue(encryptedBlob.tag, forKey: "\(key)_tag")
        
        try context.save()
    }
    
    /// CoreDataから復号化して読み込み
    func loadEncrypted<T: Codable>(_ type: T.Type, from entity: String, key: String) throws -> T? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        guard let managedObject = results.first else { return nil }
        
        guard let ciphertext = managedObject.value(forKey: "\(key)_ciphertext") as? Data,
              let nonce = managedObject.value(forKey: "\(key)_nonce") as? Data,
              let tag = managedObject.value(forKey: "\(key)_tag") as? Data else {
            return nil
        }
        
        let encryptedBlob = EncryptedBlob(ciphertext: ciphertext, nonce: nonce, tag: tag)
        let decryptedData = try vault.decrypt(encryptedBlob)
        
        return try JSONDecoder().decode(type, from: decryptedData)
    }
}
