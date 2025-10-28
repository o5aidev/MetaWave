# Xcode ファイル追加 - ステップバイステップガイド

## ✅ 準備完了

以下の3ファイルが確認できました:
- ✅ `PatternAnalysisView.swift` (13KB)
- ✅ `PredictionView.swift` (8.6KB)  
- ✅ `DataExportView.swift` (7.8KB)

## 📝 詳細手順

### 1. Xcodeでファイル追加（5分）

1. **プロジェクトナビゲーターを開く**
   - 左側パネルの一番上にある📁アイコンをクリック

2. **MetaWaveプロジェクトを展開**
   - `MetaWave` をクリックして展開
   - `Views` グループを探す
   - 見つからない場合は、`MetaWave` フォルダの中を確認

3. **ファイルを追加**
   - `Views` グループを右クリック
   - **"Add Files to MetaWave..."** を選択
   - ファイルブラウザが開く

4. **3ファイルを選択**
   - パス: `/Users/watanabekazki/Documents/Dev/MetaWave/MetaWave/Views/`
   - **Cmd** キーを押しながら以下を選択:
     - `PatternAnalysisView.swift`
     - `PredictionView.swift`
     - `DataExportView.swift`

5. **オプション設定**
   - ✅ **"Copy items if needed"**: **チェックを外す**（重要！）
   - ✅ **"Add to targets"**: `MetaWave` にチェック
   - ✅ **"Create groups"** を選択
   - **"Add"** をクリック

### 2. ContentViewを修正（2分）

1. **ContentView.swiftを開く**
   - プロジェクトナビゲーターで `ContentView.swift` をダブルクリック

2. **162-170行目を探して置き換え**

**元のコード**:
```swift
// Insights Tab
NavigationView {
    InsightsView()
}
.tabItem {
    Image(systemName: "brain.head.profile")
    Text("分析")
}
.tag(1)
```

**新しいコード**:
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
.tabItem {
    Image(systemName: "brain.head.profile")
    Text("分析")
}
.tag(1)
```

### 3. ビルド（1分）

1. **Cmd + B** を押す
2. ビルドが成功することを確認
3. エラーが出た場合は対処方法を確認

### 4. 実行テスト（2分）

1. **Cmd + R** を押す
2. シミュレーターが起動
3. アプリが表示される
4. **分析タブ**をタップ
5. **3つのサブタブ**（概要・パターン・予測）が表示されることを確認

## 🎉 完了確認

- [ ] 3ファイルがプロジェクトナビゲーターに表示される
- [ ] ビルドが成功する
- [ ] アプリが起動する
- [ ] 分析タブに3つのサブタブが表示される

## ⚡ クイックコマンド

```bash
# Xcodeプロジェクトを開く
open -a Xcode MetaWave/MetaWave.xcodeproj

# ファイルの場所を確認
ls -lh MetaWave/Views/*.swift
```

## 📞 エラーが出た場合

### "Cannot find 'XXX' in scope"
→ ファイルが正しく追加されていません
→ 手順1を再度実行

### "Duplicate symbol"
→ ファイルが重複登録されています
→ プロジェクトナビゲーターで重複を削除

---

**所要時間合計**: 約10分

