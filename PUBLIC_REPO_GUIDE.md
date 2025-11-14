# 公開リポジトリ化ガイド

## 🎯 目的
このガイドは、MetaWaveを公開リポジトリにする際の手順と注意事項をまとめたものです。

## ✅ 現在の状態

### セキュリティ面
- ✅ ハードコードされたAPIキーなし
- ✅ パスワードやトークンのハードコードなし
- ✅ 暗号化キーはKeychainに安全に保存
- ✅ 機密情報は適切に管理されている

### コード品質
- ✅ 適切なアーキテクチャ
- ✅ セキュリティベストプラクティスに準拠

## 📋 公開前のチェックリスト

### 1. 機密情報の最終確認
```bash
# 機密情報パターンの検索
grep -riE "(api[_-]?key|secret|password|token|credential)" \
  --exclude-dir=.git \
  --exclude="*.md" \
  --exclude="PUBLIC_REPO_GUIDE.md" \
  --exclude="SECURITY_CHECKLIST.md" \
  .
```

### 2. コミット履歴の確認
```bash
# 過去のコミットに機密情報が含まれていないか確認
git log --all --full-history -S "API_KEY" -S "SECRET" -S "PASSWORD"
```

### 3. 大きなファイルの確認
```bash
# 大きなファイル（機密情報が含まれている可能性）を確認
find . -type f -size +500k -not -path "./.git/*" -not -path "./DerivedData/*"
```

### 4. バイナリファイルの確認
```bash
# バイナリファイルを確認（必要に応じて除外）
find . -type f -exec file {} \; | grep -i "binary\|executable"
```

## 🚀 公開手順

### ステップ1: 最終チェック
1. `SECURITY_CHECKLIST.md`の項目をすべて確認
2. 上記のコマンドを実行して問題がないか確認

### ステップ2: リポジトリ設定
1. GitHubでリポジトリの設定を開く
2. Settings → General → Danger Zone
3. "Change repository visibility" → "Make public" を選択

### ステップ3: 公開後の確認
1. リポジトリが正しく公開されているか確認
2. 機密情報が漏洩していないか再確認
3. READMEとLICENSEが適切に表示されているか確認

## 🛡️ 公開後のセキュリティ対策

### 1. 依存関係の監視
- Dependabotを有効化して脆弱性を監視
- 定期的に依存関係を更新

### 2. セキュリティポリシー
- `SECURITY.md`を作成して脆弱性報告方法を明記
- セキュリティ関連のIssueテンプレートを作成

### 3. コードレビュー
- プルリクエストで機密情報が含まれていないか確認
- 自動化されたチェックを設定

## 📝 推奨される追加ファイル

### LICENSE
```text
MIT License または Apache 2.0 License を推奨
```

### SECURITY.md
```markdown
# セキュリティポリシー

## 脆弱性の報告

セキュリティ上の問題を発見した場合は、以下の方法で報告してください：
- Email: [your-email]
- GitHub Security Advisory: [リポジトリのSecurityタブ]
```

### CONTRIBUTING.md
```markdown
# コントリビューションガイドライン

## コードスタイル
- Swiftの標準コーディング規約に準拠
- コメントは日本語または英語

## プルリクエスト
- 機密情報を含めない
- テストを追加
- ドキュメントを更新
```

## ⚠️ 注意事項

1. **一度公開したら取り消せない**
   - 公開前にすべての機密情報を削除
   - コミット履歴も確認

2. **フォークとクローン**
   - 公開後は誰でもフォーク・クローン可能
   - コードの使用目的を制御できない

3. **ライセンスの重要性**
   - 適切なライセンスを選択
   - 商用利用の可否を明確に

## ✅ 公開準備完了の確認

- [ ] 機密情報の検索結果が空
- [ ] コミット履歴に機密情報なし
- [ ] `.gitignore`が適切に設定
- [ ] LICENSEファイルが追加済み
- [ ] READMEが適切に更新
- [ ] セキュリティチェックリスト完了

準備が整ったら、リポジトリを公開できます！


