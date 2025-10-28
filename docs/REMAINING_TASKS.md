# MetaWave 残りのタスク

**更新日**: 2025-10-28  
**バージョン**: v2.4  
**現在の完成度**: 約70%  

## ✅ 完了した機能

### 基本機能
- ✅ 音声認識（完全動作）
- ✅ ノート作成・保存
- ✅ 簡易感情分析
- ✅ ビルド成功

### バックエンド（実装済み）
- ✅ PatternAnalysisService（コード実装済み）
- ✅ PredictionService（コード実装済み）
- ✅ DataExportService（コード実装済み）
- ✅ NotificationService（コード実装済み）
- ✅ ウィジェット（コード実装済み）

## ⏳ 残りのタスク

### 優先度: 高

#### 1. Xcodeプロジェクトへのファイル登録
**ファイル**: 
- `PatternAnalysisView.swift`
- `PredictionView.swift`
- `DataExportView.swift`

**方法**:
1. Xcodeでプロジェクトを開く
2. Viewsグループを選択
3. 右クリック → "Add Files to MetaWave..."
4. 3ファイルを選択

**所要時間**: 5分

#### 2. ContentViewの修正
**現在**: `InsightsView()`を使用  
**変更**: 分析タブを3つに分割

**修正箇所**: `ContentView.swift` 162行目
```swift
// Analysis Tab
NavigationView {
    TabView {
        InsightCardsView(context: viewContext)
            .tabItem { Label("概要", systemImage: "chart.bar.fill") }
        
        PatternAnalysisView(context: viewContext)
            .tabItem { Label("パターン", systemImage: "chart.line.uptrend.xyaxis") }
        
        PredictionView(context: viewContext)
            .tabItem { Label("予測", systemImage: "crystal.ball") }
    }
}
```

**所要時間**: 5分

### 優先度: 中

#### 3. SettingsViewへのエクスポート機能追加
**ファイル**: `DataExportView.swift` (実装済み)

**修正箇所**: `SettingsView.swift`
- エクスポートボタンをNavigationLinkに変更
- DataExportViewへの遷移を追加

**所要時間**: 5分

#### 4. ウィジェットのApp Group設定
**必要な設定**:
1. Xcode Capabilities → App Groups
2. グループIDを設定
3. ウィジェットターゲットにも設定

**所要時間**: 10分

### 優先度: 低

#### 5. Item → Noteエンティティ移行
**理由**: 感情データ保存のため

**実施内容**:
- Itemの代わりにNoteエンティティを使用
- sentiment/arousalフィールドに保存

**所要時間**: 30分

## 📋 実装チェックリスト

- [ ] Xcodeプロジェクトへのファイル登録
- [ ] ContentViewの分析タブ修正
- [ ] SettingsViewのエクスポート機能追加
- [ ] ウィジェットのApp Group設定
- [ ] ビルド・実行確認
- [ ] パターン分析の表示確認
- [ ] 予測機能の表示確認
- [ ] エクスポート機能の動作確認

## 🎯 推奨実行順序

### 即座に（30分）
1. Xcodeでファイルを追加
2. ContentViewを修正
3. ビルド・実行
4. 動作確認

### 本日中（1-2時間）
5. SettingsViewの修正
6. ウィジェット設定
7. 全機能の動作確認

### 今週中
8. Item → Note移行
9. 感情データの保存
10. 最終的な動作確認

## 📊 進捗状況

| カテゴリ | 進捗 | 備考 |
|---------|------|------|
| 音声認識 | 100% | 完全動作 |
| 感情分析 | 70% | ログ出力完了、UI未表示 |
| パターン分析 | 50% | コード実装済み、ビュー未登録 |
| 予測機能 | 50% | コード実装済み、ビュー未登録 |
| エクスポート | 60% | コード実装済み、UI未統合 |
| 通知 | 80% | コード実装済み |
| ウィジェット | 40% | コード実装済み、設定未完了 |

**総合進捗**: 約70%

---

**次のアクション**: Xcodeでファイルを追加して、UIを表示させましょう！

