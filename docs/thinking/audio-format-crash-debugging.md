# オーディオフォーマットクラッシュのデバッグ過程

## 問題の特定

### エラーメッセージ
```
Format mismatch: input hw <AVAudioFormat 0x113163ed0:  1 ch,  48000 Hz, Float32>, 
client format <AVAudioFormat 0x113163200:  1 ch,  44100 Hz, Float32>
*** Terminating app due to uncaught exception 'com.apple.coreaudio.avfaudio', 
reason: 'Failed to create tap due to format mismatch'
```

### 原因分析
- **ハードウェア**: 48kHz で動作
- **アプリ設定**: 44.1kHz で固定設定
- **結果**: フォーマット不一致でクラッシュ

## 解決アプローチ

### 修正前
```swift
// 固定フォーマット（問題の原因）
let validFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: 44100.0,
    channels: 1,
    interleaved: false
)
```

### 修正後
```swift
// ハードウェアの実際のフォーマットを使用
let hardwareFormat = inputNode.outputFormat(forBus: 0)
let validFormat = hardwareFormat
```

## 学習点
- オーディオフォーマットは固定値ではなく、ハードウェアに合わせる必要がある
- デバイス間の違いを考慮した動的フォーマット選択が重要
- 実機テストの重要性（シミュレーターでは再現できない問題）
