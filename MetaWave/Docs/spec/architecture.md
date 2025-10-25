# MetaWave iOS v2.0 - アーキテクチャ仕様

## 概要

MetaWave iOS v2.0は、Miyabi仕様に基づく「メタ認知パートナー」アプリケーションです。完全ローカル処理、E2E暗号化、エッジAIを特徴とします。

## アーキテクチャ

### モジュール構成

```
MetaWave/
├── App/                    # アプリケーションエントリーポイント
├── Modules/
│   ├── StorageKit/         # 暗号化ストレージ
│   ├── InputKit/           # 音声/テキスト/画像入力
│   ├── AnalysisKit/        # 感情/ループ/バイアス分析
│   └── InsightKit/         # 介入・提案機能
├── Services/               # プロトコル定義
├── Models/                 # データモデル拡張
├── Views/                  # SwiftUI画面
└── Tests/                  # ユニットテスト
```

### セキュリティ設計

#### 暗号化フロー
1. **鍵管理**: CryptoKit `SymmetricKey` (256-bit)
2. **保存**: AES-GCM暗号化 → CoreData/UserDefaults
3. **同期**: 暗号化後データのみiCloud同期
4. **共有**: 将来の機能（v2.1+）

#### 実装詳細
- `Vault`: 暗号化・復号化の中心
- `EncryptedStorage`: 暗号化ストレージラッパー
- `Keychain`: 鍵の安全な保存

### データモデル

#### CoreDataエンティティ

**Note**
- `id`: UUID
- `createdAt/updatedAt`: Date
- `modality`: text/audio/image
- `contentText`: テキスト内容
- `audioURL/imageURL`: メディアURL
- `tags`: タグ（カンマ区切り）
- `topicHash`: トピックハッシュ
- `sentiment/arousal`: 感情スコア
- `biasSignals`: バイアス信号（JSON）
- `loopGroupID`: ループグループID
- `encNonce`: 暗号化ノンス

**Insight**
- `id`: UUID
- `noteIDs`: 関連ノートID（カンマ区切り）
- `kind`: biorhythm/loop/bias/creativity
- `payload`: 分析結果（JSON）
- `createdAt`: 作成日時

### プロトコル設計

#### Vaulting
```swift
protocol Vaulting {
    func loadOrCreateSymmetricKey() throws -> SymmetricKey
    func encrypt(_ data: Data) throws -> EncryptedBlob
    func decrypt(_ blob: EncryptedBlob) throws -> Data
}
```

#### ASRService
```swift
protocol ASRService {
    func transcribe(url: URL) async throws -> String
    func isAvailable() -> Bool
}
```

#### AnalysisServices
```swift
protocol EmotionAnalyzer {
    func analyze(audio: URL) async throws -> EmotionScore
    func analyze(text: String) async throws -> EmotionScore
}

protocol LoopDetector {
    func cluster(notes: [Note]) async throws -> [LoopCluster]
}

protocol BiasSignalDetector {
    func evaluate(notes: [Note]) async -> [BiasSignal: Float]
}
```

## 実装方針

### 段階的導入
1. **既存コード温存**: レガシー機能は維持
2. **モジュール化**: 新機能は独立モジュール
3. **プロトコル化**: 差し替え可能な設計
4. **テスト駆動**: 各モジュールにユニットテスト

### パフォーマンス考慮
- **バックグラウンド処理**: 重い分析は非同期
- **電力効率**: 低電力時は推論抑制
- **メモリ管理**: 大量データの適切な処理

## 次のステップ

1. **Day2**: ASR実装 + Capture画面
2. **Day3**: 感情分析 + 可視化
3. **Day4**: ループ検出 + バイアス分析
4. **Day5**: 剪定機能 + 統合
5. **Day6**: パフォーマンス最適化
6. **Day7**: テスト + ドキュメント
