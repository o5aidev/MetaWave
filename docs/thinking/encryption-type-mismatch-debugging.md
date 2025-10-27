# 暗号化タイプ不一致エラーのデバッグ

## 問題の特定

### エラーメッセージ
```
error: cannot convert return expression of type 'EncryptedBlob' to return type 'Data'
error: cannot convert value of type 'Data' to expected argument type 'EncryptedBlob'
```

### 原因分析
- **Vault.encrypt()**: `EncryptedBlob`型を返す
- **Vault.decrypt()**: `EncryptedBlob`型を期待
- **SpeechRecognitionService**: `Data`型で処理
- **結果**: 型の不一致でコンパイルエラー

## 解決アプローチ

### 修正前
```swift
// 型の不一致
let encryptedData = try vault.encrypt(data)  // EncryptedBlob
return encryptedData  // Data型に変換できない

let decryptedData = try vault.decrypt(encryptedData)  // Data型
```

### 修正後
```swift
// EncryptedBlobとDataの相互変換
let encryptedBlob = try vault.encrypt(data)
let encryptedData = encryptedBlob.data

let encryptedBlob = EncryptedBlob(data: encryptedData)
let decryptedData = try vault.decrypt(encryptedBlob)
```

## 学習点
- 暗号化ライブラリの型システムを理解する必要がある
- 型変換の適切な処理が重要
- エラーハンドリングと型安全性の両立
