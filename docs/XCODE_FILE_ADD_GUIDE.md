# Xcodeでファイルを追加する手順

**対象ファイル**: 以下の3ファイルをMetaWaveプロジェクトに追加

## 📋 追加するファイル

1. `MetaWave/Views/PatternAnalysisView.swift` (435行)
2. `MetaWave/Views/PredictionView.swift` (293行)
3. `MetaWave/Views/DataExportView.swift` (266行)

## 🎯 手順

### Step 1: Xcodeプロジェクトを開く
```
✅ 完了 - Xcodeが起動しました
```

### Step 2: プロジェクトナビゲーターでViewsグループを選択
1. 左側のプロジェクトナビゲーターで `MetaWave` を展開
2. `Views` グループを探す
3. もし `Views` がない場合は、`MetaWave` フォルダ内を確認

### Step 3: ファイルを追加
1. `Views` グループを右クリック
2. "Add Files to MetaWave..." を選択
3. ファイル選択ダイアログが開く
4. 以下のパスに移動: `/Users/watanabekazki/Documents/Dev/MetaWave/MetaWave/Views/`
5. 以下の3ファイルを選択（Cmd+クリックで複数選択可）:
   - `PatternAnalysisView.swift`
   - `PredictionView.swift`
   - `DataExportView.swift`
6. "Add to targets" で `MetaWave` にチェックが入っていることを確認
7. "Copy items if needed" のチェックは**外す**（既にプロジェクト内にあるため）
8. "Create groups" を選択（推奨）
9. "Finish" をクリック

### Step 4: ContentViewを修正
1. `ContentView.swift` を開く
2. 162-170行目を探す
3. 以下のコードに置き換える:

```swift
// Analysis Tab
NavigationView {
    TabView {
        // 概要
        InsightCardsView(context: viewContext)
            .tabItem {
                Label("概要", systemImage: "chart.bar.fill")
            }
        
        // パターン分析
        PatternAnalysisView(context: viewContext)
            .tabItem {
                Label("パターン", systemImage: "chart.line.uptrend.xyaxis")
            }
        
        // 予測分析
        PredictionView(context: viewContext)
            .tabItem {
                Label("予測", systemImage: "crystal.ball")
            }
    }
}
.tabItem {
    Image(systemName: "brain.head.profile")
    Text("分析")
}
.tag(1)
```

### Step 5: ビルド確認
1. Cmd+B でビルド
2. エラーがないことを確認

### Step 6: 実行テスト
1. Cmd+R でシミュレーター実行
2. アプリが起動することを確認
3. 分析タブを開いて3つのサブタブが表示されることを確認

## ⚠️ トラブルシューティング

### ファイルが見つからない場合
```bash
# ターミナルで確認
ls -lh MetaWave/Views/*.swift
```

### ビルドエラーが発生する場合
- "Cannot find 'PatternAnalysisView' in scope"
  → ファイルが正しく追加されていない可能性
  → Step 3を再度実行

- "Duplicate symbol"
  → ファイルが重複登録されている
  → プロジェクトナビゲーターで重複を削除

## 📊 完了後の確認

- [ ] プロジェクトナビゲーターに3ファイルが表示される
- [ ] ビルドが成功する
- [ ] 分析タブに3つのサブタブが表示される
- [ ] パターン分析ビューが表示される
- [ ] 予測ビューが表示される

---

**所要時間**: 約5-10分

