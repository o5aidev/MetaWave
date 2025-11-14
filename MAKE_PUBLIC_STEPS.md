# リポジトリを公開する手順（ターミナル版）

## ステップ1: 現在の状態を確認

```bash
# 1-1. 現在のブランチと状態を確認
git status

# 1-2. 機密情報が含まれていないか最終確認
grep -riE "(api[_-]?key|secret|password|token|credential)" \
  --exclude-dir=.git \
  --exclude-dir=DerivedData \
  --exclude="*.md" \
  --exclude="*.xcworkspace" \
  --exclude="*.xcodeproj" \
  . | grep -v "kSecClassGenericPassword" | grep -v "gitignore" | grep -v "\.miyabi.yml.*#"

# 1-3. 大きなファイルやバイナリファイルを確認（オプション）
find . -type f -size +500k -not -path "./.git/*" -not -path "./DerivedData/*" 2>/dev/null
```

## ステップ2: 変更をコミット（必要に応じて）

```bash
# 2-1. 追加したファイルを確認
git status

# 2-2. セキュリティ関連のファイルを追加
git add .gitignore SECURITY_CHECKLIST.md PUBLIC_REPO_GUIDE.md MAKE_PUBLIC_STEPS.md

# 2-3. コミット
git commit -m "docs: add security checklist and public repo guide

- Enhanced .gitignore with security patterns
- Added SECURITY_CHECKLIST.md for pre-publication checks
- Added PUBLIC_REPO_GUIDE.md with step-by-step instructions
- Added MAKE_PUBLIC_STEPS.md with terminal commands"
```

## ステップ3: リモートにプッシュ

```bash
# 3-1. 現在のブランチを確認
git branch

# 3-2. リモートにプッシュ
git push origin ci/add-xcodebuild-test

# または、mainブランチにマージしてからプッシュする場合：
# git checkout main
# git merge ci/add-xcodebuild-test
# git push origin main
```

## ステップ4: GitHubでリポジトリを公開

**注意**: このステップはGitHubのWeb UIで行います（ターミナルからは直接できません）

1. ブラウザで https://github.com/o5aidev/MetaWave を開く
2. Settings → General に移動
3. 一番下の "Danger Zone" セクションを開く
4. "Change repository visibility" をクリック
5. "Make public" を選択
6. リポジトリ名を入力して確認
7. "I understand, change repository visibility" をクリック

## ステップ5: 公開後の確認

```bash
# 5-1. リポジトリが公開されているか確認（ブラウザで）
# https://github.com/o5aidev/MetaWave にアクセスして、公開されているか確認

# 5-2. GitHub Actionsが動作するか確認
# GitHubのActionsタブで、最新のワークフローが実行されているか確認

# 5-3. 機密情報が漏洩していないか再確認
git log --all --source -S "API_KEY" -S "SECRET" -S "PASSWORD" --oneline
```

## トラブルシューティング

### 機密情報が見つかった場合
```bash
# 機密情報を含むファイルを特定
grep -riE "(api[_-]?key|secret|password|token)" --exclude-dir=.git .

# 該当ファイルを編集して機密情報を削除
# その後、.gitignoreに追加して再コミット
```

### コミット履歴に機密情報が含まれている場合
```bash
# git-filter-repoを使用して履歴を書き換える（注意：履歴を変更します）
# または、新しいリポジトリを作成してコードをコピー
```

## 完了確認

- [ ] 機密情報の検索結果が空または安全
- [ ] 変更をコミット・プッシュ済み
- [ ] GitHubでリポジトリを公開済み
- [ ] GitHub Actionsが正常に動作している
- [ ] リポジトリが公開されていることを確認

準備完了です！


