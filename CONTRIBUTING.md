# コントリビューションガイドライン

MetaWaveプロジェクトへの貢献をありがとうございます！このドキュメントは、プロジェクトへの貢献方法を説明しています。

## 🚀 はじめに

### 開発環境のセットアップ

1. リポジトリをクローン:
```bash
git clone https://github.com/o5aidev/MetaWave.git
cd MetaWave
```

2. Xcodeでプロジェクトを開く:
```bash
open MetaWave/MetaWave.xcodeproj
```

3. ビルドを確認:
- Xcodeでターゲット `MetaWave` を選択
- `Cmd+B` でビルド
- エラーがないことを確認

## 📝 コーディング規約

### Swiftスタイルガイド

- **命名規則**: Swift API Design Guidelinesに準拠
- **インデント**: 4スペース（タブは使用しない）
- **コメント**: 日本語または英語で記述
- **アクセス修飾子**: 明示的に指定

### アーキテクチャ

- **MVVMパターン**: View、ViewModel、Modelを明確に分離
- **依存性注入**: テスト容易性のため
- **非同期処理**: async/awaitを使用

### コード例

```swift
// ✅ Good
final class AnalysisService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func analyze() async throws -> AnalysisResult {
        // 実装
    }
}

// ❌ Bad
class AnalysisService {
    var context: NSManagedObjectContext?
    
    func analyze() {
        // 実装
    }
}
```

## 🔀 ブランチ戦略

### ブランチ命名規則

- `feature/機能名`: 新機能の開発
- `fix/バグ修正名`: バグ修正
- `docs/ドキュメント名`: ドキュメント更新
- `refactor/リファクタリング名`: リファクタリング
- `test/テスト名`: テスト追加・改善

### 例

```bash
git checkout -b feature/voice-recognition-improvement
git checkout -b fix/memory-leak-in-analysis
git checkout -b docs/update-readme
```

## 📤 プルリクエストの作成

### 1. ブランチを作成

```bash
git checkout -b feature/my-feature
```

### 2. 変更をコミット

```bash
git add .
git commit -m "feat: add new feature"
```

コミットメッセージの形式:
- `feat: 新機能追加`
- `fix: バグ修正`
- `docs: ドキュメント更新`
- `refactor: リファクタリング`
- `test: テスト追加`
- `perf: パフォーマンス改善`

### 3. ブランチをプッシュ

```bash
git push origin feature/my-feature
```

### 4. プルリクエストを作成

1. GitHubで「New Pull Request」をクリック
2. ベースブランチを`main`に設定
3. 変更内容を説明
4. 関連するIssueがあればリンク

### プルリクエストのチェックリスト

- [ ] コードがビルドできる
- [ ] テストが通る（可能な場合）
- [ ] コーディング規約に準拠している
- [ ] ドキュメントを更新した（必要に応じて）
- [ ] コミットメッセージが適切

## 🧪 テスト

### テストの実行

```bash
# Xcodeで
⌘U でテスト実行

# コマンドラインで
xcodebuild test -scheme MetaWave -destination 'platform=iOS Simulator,name=iPhone 15'
```

### テストの書き方

- 各機能に対してユニットテストを書く
- 統合テストで主要なフローをカバー
- エッジケースもテストする

## 🐛 バグ報告

### Issueの作成

バグを発見した場合は、以下の情報を含めてIssueを作成してください：

1. **バグの説明**: 何が起こったか
2. **再現手順**: バグを再現する手順
3. **期待される動作**: どうなるべきか
4. **実際の動作**: 実際にどうなったか
5. **環境情報**: 
   - iOSバージョン
   - デバイス/シミュレーター
   - アプリバージョン

### Issueテンプレート

```markdown
## バグの説明
[簡潔に説明]

## 再現手順
1. 
2. 
3. 

## 期待される動作
[説明]

## 実際の動作
[説明]

## 環境
- iOS: 
- デバイス: 
- アプリバージョン: 
```

## 💡 機能提案

新機能の提案も歓迎します！

### 提案の内容

- **機能の説明**: 何を実現したいか
- **ユースケース**: どのような場面で使うか
- **実装のアイデア**: どのように実装するか（オプション）

## 📚 ドキュメント

### ドキュメントの更新

- コード変更に伴い、関連するドキュメントも更新してください
- README.md、コメント、ドキュメントファイルを確認

## ✅ コードレビュー

### レビュアーへの配慮

- 変更内容を明確に説明する
- 大きな変更は小さく分割する
- レビューコメントに対して適切に対応する

### レビュー時の確認事項

- コードの品質
- テストのカバレッジ
- パフォーマンスへの影響
- セキュリティへの配慮

## 🎯 優先順位

### 高優先度

- セキュリティ関連のバグ修正
- データ損失に関わるバグ修正
- クラッシュの修正

### 中優先度

- 機能追加
- UI改善
- パフォーマンス最適化

### 低優先度

- ドキュメント更新
- リファクタリング
- コードスタイルの改善

## 📞 質問・相談

質問や相談がある場合は、以下でお気軽にどうぞ：

- GitHub Issues: 技術的な質問
- Discussions: 一般的な議論やアイデア

## 🙏 謝辞

MetaWaveプロジェクトへの貢献をありがとうございます！
皆様の貢献が、より良いアプリを作る原動力です。

---

**Happy Coding! 🚀**


