# MetaWave ドキュメント

## ディレクトリ構成

### `thinking/` - 設計判断と思考過程
設計判断や思考過程を外部化し、Claudeが設計意図を理解できる形で記録します。

- `cloudkit-integration-decision.md` - CloudKit統合の判断過程
- `audio-format-crash-debugging.md` - オーディオフォーマットクラッシュのデバッグ過程
- `continuation-resume-error-debugging.md` - CheckedContinuation重複resumeエラーのデバッグ過程
- `button-ui-state-management.md` - ボタンUI状態管理のデバッグ過程
- `continuous-speech-recognition-design.md` - 連続音声認識の設計判断
- `no-speech-detected-error-handling.md` - "No speech detected"エラーの処理判断
- `empty-result-fix-debugging.md` - 空の結果が返される問題の修正過程

### `features/` - 新機能の実装仕様
新機能の追加・改修の目的と背景を記録します。

- `speech-recognition-v2.1.md` - 音声入力機能 (v2.1) 実装仕様
- `security-modules.md` - セキュリティモジュール実装仕様
- `core-data-persistence.md` - Core Data永続化実装仕様

### `deleted/` - 削除・廃止機能の履歴
削除・廃止した機能やファイルの履歴を残します。

- `cloudkit-integration-files.md` - CloudKit統合関連ファイルの削除
- `legacy-voice-input-files.md` - 旧版音声入力ファイルの削除

## 運用ルール

### 記録内容
- **thinking/**: 迷った点、却下した案、判断理由などを短文で残す
- **features/**: 実装目的、画面構成、データ構造、リスク、完了条件などを簡潔にまとめる
- **deleted/**: 削除理由、影響範囲、代替手段、再発防止策を記録する

### 更新タイミング
- **thinking/**: 設計判断やデバッグ過程で迷った時
- **features/**: 新機能実装時や既存機能の大幅改修時
- **deleted/**: ファイルや機能を削除・廃止する時

### 記録形式
- **Markdown形式**: 読みやすさと検索性を重視
- **簡潔な記録**: 要点を絞った記録
- **技術的詳細**: 実装の詳細も含める
- **判断理由**: なぜその判断をしたかの理由を明記

## 開発経緯

### v2.1 音声認識機能開発
- **期間**: 2024年10月
- **主要機能**: 連続音声認識、リアルタイム表示、暗号化
- **技術課題**: オーディオフォーマット、非同期処理、UI状態管理
- **成果**: 完全動作する音声入力機能の実装

### 主要な技術判断
1. **CloudKit統合の中止**: 個人開発チームの制約を考慮
2. **オーディオフォーマット最適化**: ハードウェアに合わせた動的設定
3. **連続音声認識**: ユーザー体験を重視した設計
4. **エラーハンドリング**: 堅牢なエラー処理の実装

## 今後の展開

### v2.2 予定機能
- クラウド同期機能
- 音声データ共有機能
- 高度な分析機能

### ドキュメント更新
- 新機能実装時の仕様記録
- 設計判断の記録
- 削除・廃止機能の履歴管理
