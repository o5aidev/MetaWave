# Cursor Agent Terminal ウィンドウ削除手順

**作成日**: 2025-10-29  
**問題**: 透明な「MetaWave --zsh - 213x66」ウィンドウが残存  
**原因**: Cursor.appのAgent terminals（読み取り専用）

## 現状
- 複数ウィンドウで開発中のため⌘ + Q不可
- Command+W送信済みだが残存
- 無害だが視覚的に邪魔

## 削除手順（優先順位順）

### 1. 開発終了後の対応
```bash
# Cursor.appを完全終了
killall Cursor
# または
osascript -e 'tell application "Cursor" to quit'
```

### 2. 特定ウィンドウの削除
```bash
# Cursorの特定ウィンドウを閉じる
osascript << 'EOF'
tell application "System Events"
    tell process "Cursor"
        try
            set frontmost to true
            keystroke "w" using command down
            delay 0.5
            keystroke "w" using command down
        end try
    end tell
end tell
EOF
```

### 3. 強制削除（最後の手段）
```bash
# Cursorの全プロセスを強制終了
pkill -f "Cursor"
# または
sudo killall -9 Cursor
```

### 4. システム再起動
- 上記で解決しない場合のみ
- 全プロセスがクリーンアップされる

## 実行タイミング
- 開発セッション終了時
- 次の開発開始前
- ユーザーが明示的に要求した時

## 注意事項
- Agent terminalsは無害
- 開発作業に影響なし
- 必要に応じて無視可能

## 記録
- 2025-10-29: 問題発生、Command+W送信済み
- 2025-10-29: 削除手順を記録
