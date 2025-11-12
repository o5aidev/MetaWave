# CI Setup

## Summary
- Added `.github/workflows/ci.yml` to run `xcodebuild build/test` on macOS GitHub Actions runners.
- Xcode 15.4 is installed via `maxim-lobanov/setup-xcode@v1`.
- Optional steps handle Bundler/CocoaPods installs, and build logs are uploaded as artifacts.

## Notes
- macOS ランナーは無料枠の利用でも支払い方法の登録が必要。
- ワークフローが安定したら `main` ブランチにステータスチェック必須ルールを追加する。
- 追加の改善案: DerivedData キャッシュ、マトリクスでの複数デバイス検証など。
