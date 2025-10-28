# MetaWave

**メタ認知パートナー** - 思考と行動を記録・分析するiOSアプリ

## 📱 概要

MetaWaveは、ユーザーの思考、感情、行動パターンを記録・分析し、自己理解を深めるためのメタ認知パートナーアプリです。音声やテキストで思考を記録し、AIによる感情分析とパターン分析で洞察を提供します。

## ✨ 主な機能

### v2.4 (最新版)
- ✅ **データエクスポート**: JSON/CSV形式でデータをエクスポート
- ✅ **プッシュ通知**: 記録リマインダーとパターン検出通知
- ✅ **パターン分析**: 24時間、週間、30日間の感情パターン可視化
- ✅ **予測機能**: 感情トレンド、ループパターン、バイアス検出の予測
- ✅ **高度な感情分析**: 6種類の感情を同時検出、強度数値化

### 以前のバージョン
- v2.3: 高度な分析機能・AI統合
- v2.2: CloudKit統合削除、ローカル保存のみ
- v2.1: 音声認識機能完全実装
- v2.0: メタ認知機能基本実装

## 🚀 セットアップ

### 必要要件
- iOS 15.0以上
- Xcode 14.0以上
- Swift 5.5以上

### インストール

1. リポジトリをクローン:
```bash
git clone https://github.com/o5aidev/MetaWave.git
cd MetaWave
```

2. Xcodeでプロジェクトを開く:
```bash
open MetaWave/MetaWave.xcodeproj
```

3. ビルド & 実行:
- Xcodeでターゲット `MetaWave` を選択
- `Cmd+R` でシミュレーター/デバイスで実行

## 📁 プロジェクト構成

```
MetaWave/
├── Core/                    # コア機能
│   └── Security/           # 暗号化モジュール
├── Models/                  # データモデル
├── Modules/                 # 機能モジュール
│   ├── AnalysisKit/        # 分析機能
│   ├── InputKit/           # 入力機能（音声認識）
│   ├── InsightKit/         # インサイト機能
│   └── StorageKit/         # ストレージ機能
├── Services/               # サービス層
│   ├── AnalysisService.swift
│   ├── DataExportService.swift
│   ├── NotificationService.swift
│   ├── PatternAnalysisService.swift
│   └── PredictionService.swift
├── Views/                  # UIビュー
│   ├── ContentView.swift
│   ├── DataExportView.swift
│   ├── InsightCards.swift
│   ├── PatternAnalysisView.swift
│   ├── PredictionView.swift
│   └── SettingsView.swift
├── Tests/                  # テスト
└── Docs/                   # ドキュメント
    ├── RELEASE_NOTES.md
    └── RELEASE_NOTES_v2.3.md
```

## 🔒 セキュリティ

- **暗号化**: AES-256-GCMでデータを暗号化
- **ローカル保存**: データはデバイス内のみ保存、外部送信なし
- **鍵管理**: Keychainを使用した安全な鍵管理
- **プライバシー**: 全ての処理はデバイス内で実行

## 🧪 テスト

```bash
# テスト実行
xcodebuild test -scheme MetaWave -destination 'platform=iOS Simulator,name=iPhone 15'
```

テストカバレッジ:
- 単体テスト: 感情分析、ループ検出、バイアス検出
- 統合テスト: 分析フロー、データ整合性
- UIテスト: ビューコンポーネント
- パフォーマンステスト: Core Data、メモリ最適化

## 📊 パフォーマンス

- **メモリ使用量**: ~30%削減 (v2.3での改善)
- **フェッチ速度**: ~20%向上 (Core Data最適化)
- **UI応答性**: 最適化済み

## 🛠️ 開発

### コーディング規約
- Swift 5.5以上
- async/await パターン使用
- SwiftUI ベストプラクティス
- MVVM アーキテクチャ

### コミット規約
```
feat: 新機能追加
fix: バグ修正
docs: ドキュメント更新
refactor: リファクタリング
perf: パフォーマンス改善
test: テスト追加
```

### ブランチ戦略
- `main`: 本番環境
- `feature/*`: 新機能開発
- `release/*`: リリース準備
- `hotfix/*`: 緊急修正

## 📚 ドキュメント

### ドキュメント一覧
- [開発ロードマップ](docs/features/development-roadmap-summary.md)
- [v2.3 リリースノート](MetaWave/Docs/RELEASE_NOTES_v2.3.md)
- [v2.4 計画](docs/features/v2.4-feature-plan.md)
- [テスト戦略](docs/features/testing-strategy.md)
- [品質改善](docs/features/quality-improvements.md)

### アーキテクチャ
- Core Data: データ永続化
- SwiftUI: UI実装
- UserNotifications: プッシュ通知
- AVFoundation: 音声認識

## 🤝 貢献

### プルリクエストの作り方
1. 新しいブランチを作成: `git checkout -b feature/my-feature`
2. 変更をコミット: `git commit -m "feat: my feature"`
3. ブランチをプッシュ: `git push origin feature/my-feature`
4. プルリクエストを作成

## 📝 ライセンス

このプロジェクトは非公開プロジェクトです。

## 🗺️ ロードマップ

### 完了済み
- ✅ v2.3: 高度な分析機能・AI統合
- ✅ v2.4: データエクスポート・通知機能

### 今後予定
- [ ] v2.5: ウィジェット対応
- [ ] v2.6: 可視化強化
- [ ] v3.0: エンタープライズ対応

## 📞 サポート

問題や質問がある場合は、GitHubのIssuesで報告してください。

---

**MetaWave**: より良い自己理解のために ✨
