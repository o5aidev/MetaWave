# MetaWave プロジェクト概要

## プロジェクト情報

**プロジェクト名**: MetaWave  
**バージョン**: 2.4.0  
**プラットフォーム**: iOS 15.0+  
**言語**: Swift 5.5+  
**フレームワーク**: SwiftUI, Core Data, AVFoundation  

## 目的

MetaWaveは、ユーザーの思考、感情、行動パターンを記録・分析し、自己理解を深めるためのメタ認知パートナーアプリです。

## 主要機能

### 1. 記録機能
- **テキスト記録**: テキストによる思考記録
- **音声記録**: 音声認識による記録 (v2.1)
- **暗号化**: AES-256-GCMでデータ保護

### 2. 分析機能
- **感情分析**: 6種類の感情を検出
- **ループ検出**: 繰り返し思考パターンの検出
- **バイアス検出**: 認知バイアスの特定
- **パターン分析**: 時間帯・週間・推移分析 (v2.3)
- **予測機能**: 感情トレンド、ループパターン予測 (v2.3)

### 3. 可視化
- **統計情報**: ノート数、感情スコア
- **パターングラフ**: 24時間、週間、30日間
- **予測カード**: 信頼度と影響度付き
- **インサイト**: 自己理解のための洞察

### 4. データ管理
- **エクスポート**: JSON/CSV形式 (v2.4)
- **ローカル保存**: Core Data使用
- **暗号化**: Vaultによる安全な保存

### 5. 通知 (v2.4)
- **日次リマインダー**: 記録の習慣化
- **パターン通知**: 新しいパターン検出時
- **トレンド通知**: 感情トレンド変化時

## アーキテクチャ

### MVVM パターン
```
View (SwiftUI)
  ↓
ViewModel (@Published, @StateObject)
  ↓
Model (Core Data)
```

### レイヤー構造

1. **Presentation Layer**
   - SwiftUI Views
   - ViewModels
   - State Management

2. **Business Logic Layer**
   - Services
   - Analyzers
   - Detectors

3. **Data Layer**
   - Core Data
   - Vault (Encryption)
   - Keychain

### モジュール構成

```
Modules/
├── AnalysisKit/           # 分析機能
│   ├── TextEmotionAnalyzer
│   ├── AdvancedEmotionAnalyzer (v2.3)
│   ├── TextLoopDetector
│   ├── BiasDetector
│   └── VoiceEmotionAnalyzer
├── InputKit/              # 入力機能
│   ├── SpeechRecognitionService
│   └── AppleASRService
├── InsightKit/            # インサイト
│   └── PruningService
└── StorageKit/            # ストレージ
    └── EncryptedStorage
```

## データモデル

### Core Data エンティティ

1. **Note**
   - 記録の基本エンティティ
   - modality: text/voice
   - contentText: テキスト内容
   - audioURL: 音声URL
   - sentiment: 感情スコア
   - arousal: 覚醒度
   - createdAt, updatedAt

2. **Insight**
   - 分析結果
   - kind: インサイト種類
   - payload: JSONデータ
   - noteIDs: 関連ノート

3. **Item** (Legacy)
   - 旧バージョンとの互換性

## セキュリティ

### 暗号化戦略

1. **Vault**
   - AES-256-GCM暗号化
   - デバイス固有鍵
   - Keychain保存

2. **データ保護**
   - ロcalストレージのみ
   - 外部送信なし
   - プライバシー重視

## パフォーマンス

### 最適化済み

1. **Core Data**
   - stalenessInterval = 0.0
   - undoManager = nil
   - fetchBatchSize = 20
   - メモリ ~30%削減

2. **音声認識**
   - バッファサイズ 2048
   - 10MB制限

3. **UI**
   - バッチフェッチ
   - 非同期処理
   - 進捗表示

## テスト

### カバレッジ

- **単体テスト**: AnalysisKit
- **統合テスト**: 分析フロー
- **UIテスト**: Views
- **パフォーマンステスト**: Core Data

### テストファイル

```
Tests/
├── EmotionAnalysisTests.swift
├── IntegrationTests.swift
├── PerformanceOptimizationTests.swift
├── UIIntegrationTests.swift
└── VaultTests.swift
```

## バージョン履歴

### v2.4 (2025-10-28)
- データエクスポート機能
- プッシュ通知機能
- 改善: メモリ最適化、テスト追加

### v2.3 (2025-10-28)
- 高度な感情分析
- パターン分析
- 予測機能
- UI統合

### v2.2
- CloudKit統合削除
- ローカル保存のみ

### v2.1
- 音声認識機能
- 暗号化音声保存

### v2.0
- 基本機能実装
- 感情分析
- ループ検出

## 今後の展開

### 短期 (1ヶ月)
- ウィジェット対応
- UI改善

### 中期 (3ヶ月)
- エクスポート強化
- 可視化改善

### 長期 (6ヶ月)
- エンタープライズ対応
- 高度な分析機能

## 開発チーム

MetaWave開発チーム

## 関連リンク

- [GitHub Repository](https://github.com/o5aidev/MetaWave)
- [ドキュメント](docs/)
- [リリースノート](MetaWave/Docs/)

---

**最終更新**: 2025-10-28

