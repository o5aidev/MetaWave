# "No speech detected"エラーの処理判断

## 問題の特定

### エラーメッセージ
```
❌ 音声認識エラー: No speech detected
```

### 原因分析
- **音声なし**: ユーザーが話さなかった
- **音声認識**: 音声が検出されなかった
- **結果**: エラーとして扱われていた

## 解決アプローチ

### 修正前
```swift
// エラーとして扱う
continuation.resume(throwing: SpeechRecognitionError.recognitionError(errorMessage))
```

### 修正後
```swift
// "No speech detected"は正常な終了として扱う
if error.localizedDescription.contains("No speech detected") {
    let recognitionResult = SpeechRecognitionResult(
        text: lastValidText, // 最後の有効なテキストを使用
        confidence: 0.0,
        duration: duration,
        audioData: audioData,
        timestamp: startTime
    )
    continuation.resume(returning: recognitionResult)
}
```

## 学習点
- エラーの種類によって処理を分岐する必要がある
- ユーザー体験を考慮したエラーハンドリングが重要
- 正常な終了パターンも想定した設計
