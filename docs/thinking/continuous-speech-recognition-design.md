# 連続音声認識の設計判断

## 要件
- **ユーザー制御**: ストップボタンを押すまで音声認識を継続
- **リアルタイム表示**: 部分結果を即座にUIに反映
- **自然な操作**: 長い文章も一気に話せる

## 設計判断

### 部分結果の処理
```swift
// 修正前: 最初の結果で即座に完了
continuation.resume(returning: recognitionResult)

// 修正後: 部分結果を蓄積、isFinalまで待機
if result.isFinal {
    continuation.resume(returning: recognitionResult)
} else {
    // 部分結果をUIに通知
    NotificationCenter.default.post(...)
}
```

### UI更新の仕組み
- **NotificationCenter**: 部分結果の通知
- **リアルタイム更新**: 認識結果の即座反映
- **状態管理**: 録音中/停止中の適切な制御

## 学習点
- 連続認識では部分結果の処理が重要
- NotificationCenterは非同期UI更新に有効
- ユーザー体験を重視した設計判断
