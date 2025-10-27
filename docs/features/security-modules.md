# セキュリティモジュール実装仕様

## 実装目的
- **データ暗号化**: 音声データの完全暗号化
- **キー管理**: セキュアな暗号化キーの管理
- **プライバシー保護**: ユーザーデータの保護
- **ローカル処理**: 外部送信なしの処理

## モジュール構成

### Vault.swift
- **暗号化エンジン**: AES-GCM 256による暗号化
- **キー生成**: セキュアな暗号化キーの生成
- **データ保護**: 音声データの暗号化/復号化

### Keychain.swift
- **キー保存**: 暗号化キーの安全な保存
- **アクセス制御**: セキュアなキーアクセス
- **データ永続化**: アプリ再起動後のキー復元

### Migration.swift
- **キー移行**: 旧フォーマットからの移行
- **互換性**: バージョン間の互換性確保
- **データ整合性**: 移行時のデータ保護

## データ構造

### 暗号化キー
- **SymmetricKey**: CryptoKitによる対称鍵
- **キーサイズ**: 256bit
- **アルゴリズム**: AES-GCM

### 暗号化データ
- **EncryptedBlob**: 暗号化されたデータ構造
- **IV**: 初期化ベクトル
- **Tag**: 認証タグ

## 技術実装

### 暗号化処理
```swift
func encrypt(_ data: Data) throws -> Data {
    let key = try getOrCreateKey()
    let sealedBox = try AES.GCM.seal(data, using: key)
    return sealedBox.combined!
}
```

### キー管理
```swift
func generateOrLoadVaultKey() throws -> SymmetricKey {
    if let existingKey = loadKeyFromKeychain() {
        return existingKey
    }
    let newKey = SymmetricKey(size: .bits256)
    try saveKeyToKeychain(newKey)
    return newKey
}
```

## セキュリティ要件

### 暗号化強度
- **アルゴリズム**: AES-GCM 256
- **キー管理**: Secure Enclave + Keychain
- **データ保護**: 完全ローカル処理

### プライバシー保護
- **外部送信なし**: 音声データの外部送信禁止
- **ユーザー制御**: データの保存/削除制御
- **最小権限**: 必要最小限の権限要求

## リスク

### セキュリティリスク
- **キー漏洩**: 暗号化キーの保護
- **データ復号**: 暗号化データの復号化
- **権限管理**: 適切な権限設定

### 技術的リスク
- **キー管理**: 複雑なキー管理ロジック
- **互換性**: バージョン間の互換性
- **パフォーマンス**: 暗号化処理の負荷

## 完了条件

### 機能要件
- ✅ 音声データの暗号化
- ✅ 暗号化キーの管理
- ✅ データの復号化
- ✅ キーの永続化

### セキュリティ要件
- ✅ AES-GCM 256暗号化
- ✅ Secure Enclaveキー管理
- ✅ 完全ローカル処理
- ✅ データの完全削除
