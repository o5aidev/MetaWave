# 公開リポジトリ化前のセキュリティチェックリスト

## ✅ 確認済み項目

### 1. コードベースの確認
- ✅ ハードコードされたAPIキーなし
- ✅ パスワードやトークンのハードコードなし
- ✅ 暗号化キーはKeychainに保存（適切）
- ✅ Vault実装は安全（AES-GCM 256）

### 2. ファイル管理
- ✅ `.gitignore`に機密ファイルパターンを追加
- ✅ 環境変数ファイル（`.env`）を除外

## 🔍 公開前に確認すべき項目

### 1. コミット履歴の確認
```bash
# 過去のコミットに機密情報が含まれていないか確認
git log --all --full-history --source -- "*secret*" "*key*" "*password*" "*token*"
git log --all --full-history -S "API_KEY" -S "SECRET" -S "PASSWORD"
```

### 2. 機密情報の検索
```bash
# コード内の機密情報パターンを検索
grep -r "api[_-]key\|secret\|password\|token" --include="*.swift" --include="*.plist" --include="*.json" .
```

### 3. 設定ファイルの確認
- [ ] `Info.plist`に機密情報がないか確認
- [ ] `entitlements`ファイルに機密情報がないか確認
- [ ] 設定ファイル（JSON/YAML）に機密情報がないか確認

### 4. コメント内の機密情報
- [ ] コメントにAPIキーやパスワードが書かれていないか確認
- [ ] TODOコメントに機密情報が含まれていないか確認

## 🛡️ 公開後の対策

### 1. 環境変数の使用（将来の拡張用）
もし将来的にAPIキーなどが必要になった場合：

```swift
// Config.swift (テンプレート)
struct Config {
    static var apiKey: String {
        // 環境変数から読み込む
        if let key = ProcessInfo.processInfo.environment["API_KEY"] {
            return key
        }
        // 開発用のデフォルト（本番では使用しない）
        return "development-key"
    }
}
```

### 2. GitHub Secretsの使用（CI/CD用）
CI/CDで機密情報が必要な場合：
- GitHubリポジトリの Settings → Secrets and variables → Actions
- シークレットを追加して、ワークフローで `${{ secrets.SECRET_NAME }}` として使用

### 3. 定期的な監査
- 定期的にコードベースをスキャン
- 依存関係の脆弱性チェック
- セキュリティアップデートの適用

## 📝 公開時の注意事項

1. **ライセンスの明記**
   - `LICENSE`ファイルを追加
   - MIT、Apache 2.0など適切なライセンスを選択

2. **READMEの更新**
   - セキュリティポリシーの記載
   - 脆弱性報告方法の記載

3. **CONTRIBUTING.mdの作成**
   - コントリビューションガイドライン
   - コードスタイルの統一

## ✅ 最終チェックコマンド

```bash
# 1. 機密情報の検索
grep -ri "password\|secret\|api.*key\|token" --exclude-dir=.git --exclude="*.md" .

# 2. コミット履歴の確認
git log --all --source -- "*secret*" "*key*"

# 3. 大きなファイルの確認（機密情報が含まれている可能性）
find . -type f -size +1M -not -path "./.git/*"

# 4. バイナリファイルの確認
find . -type f -exec file {} \; | grep -i "binary\|executable"
```


