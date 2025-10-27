# CheckedContinuation重複resumeエラーのデバッグ過程

## 問題の特定

### エラーメッセージ
```
Fatal error: SWIFT TASK CONTINUATION MISUSE: startRecognition() tried to resume its continuation more than once, throwing recognitionError("音声認識エラー: Recognition request was canceled")!
```

### 原因分析
- **音声認識コールバック**: 複数回呼ばれる可能性
- **continuation**: 1回のみresume可能
- **結果**: 重複resumeでクラッシュ

## 解決アプローチ

### 修正前
```swift
// 重複resumeの可能性
continuation.resume(throwing: SpeechRecognitionError.recognitionError(errorMessage))
continuation.resume(returning: recognitionResult)
```

### 修正後
```swift
// 重複防止フラグ
var hasResumed = false
guard !hasResumed else { return }
hasResumed = true
continuation.resume(...)
```

## 学習点
- 非同期処理では状態管理が重要
- コールバックの重複呼び出しを想定した設計が必要
- フラグによる制御は基本的だが効果的
