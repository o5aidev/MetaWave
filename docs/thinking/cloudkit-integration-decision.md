# CloudKit統合の判断過程

## 判断の経緯

### 初期方針: CloudKit統合
- **目的**: iCloud同期によるデータの永続化とマルチデバイス対応
- **実装**: `NSPersistentCloudKitContainer`への移行
- **設定**: `NSPersistentHistoryTrackingKey`、`NSPersistentStoreRemoteChangeNotificationPostOptionKey`の追加

### 判断変更: ローカル保存への回帰
- **理由**: 個人開発チームではCloudKitの制約が厳しい
- **制約**: 有料Apple Developer Programが必要
- **影響**: 開発・テスト環境での制限

### 最終判断
- **方針**: 完全ローカル保存（`NSPersistentContainer`）
- **理由**: 開発効率とコストを優先
- **将来性**: v2.2で再検討予定

## 技術的影響
- **Persistence.swift**: CloudKit関連コードの削除
- **entitlements**: CloudKit権限の削除
- **データ同期**: 将来的な課題として残存

## 学習点
- クラウド統合は開発段階での制約を事前に確認する必要がある
- 個人開発では段階的なアプローチが重要
