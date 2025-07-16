# DocKeeper v2.2.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-15.5+-blue.svg)](https://www.apple.com/macos/)
[![Homebrew](https://img.shields.io/badge/Homebrew-4.0+-orange.svg)](https://brew.sh)

**Homebrew Cask更新時のDockアイコン自動復元ツール**

## TL;DR

```bash
cd dock-keeper
./dockeeper.sh --dry-run  # テスト実行
./dockeeper.sh            # 実際に実行
```

Homebrew でアプリを更新すると Dock から消えるアイコンを **自動で復元** します。

---

## 🚀 主な機能

- ✅ **Homebrew Cask 一括更新**: 標準 `brew upgrade --cask --greedy` による全 Cask アップデート
- 🔄 **Dock アイコン自動復元**: 更新で消失したアイコンを元の位置に復元
- 🔍 **Dry-run モード**: 実際の変更なしで動作確認
- 📊 **進捗表示**: プログレスバー付きの詳細ログ
- 🎨 **カラー出力**: エラー・警告・成功を色分け表示
- 🛠️ **依存関係自動検出**: 必要なツールを自動検出・インストール

---

## 📋 システム要件

| 項目 | 要件 | 自動インストール |
|------|------|------------------|
| **macOS** | 15.5+ | ❌ |
| **Homebrew** | 4.0+ | ❌ |
| **dockutil** | latest | ✅ |

---

## 🔧 インストール & 使用方法

### 1. 基本セットアップ

```bash
# リポジトリクローン
git clone <repository-url>
cd minitools/dock-keeper

# 実行権限付与
chmod +x dockeeper.sh

# 依存関係チェック（dry-run）
./dockeeper.sh --dry-run
```

### 2. 基本実行

```bash
# 通常実行（推奨）
./dockeeper.sh

# 詳細ログ付き実行
./dockeeper.sh --verbose
```

### 3. コマンドオプション

| オプション | 説明 | 使用例 |
|-----------|------|--------|
| `-n, --dry-run` | テスト実行（変更なし） | `./dockeeper.sh --dry-run` |
| `-v, --verbose` | 詳細ログ表示 | `./dockeeper.sh -v` |
| `-h, --help` | ヘルプ表示 | `./dockeeper.sh --help` |
| `--version` | バージョン表示 | `./dockeeper.sh --version` |

---

## 🔒 セキュリティ機能

### 🛡️ セキュリティ対策
- ✅ **コマンドインジェクション対策**: 全パラメータの厳密な検証
- ✅ **パス・トラバーサル防止**: ディレクトリ作成時の安全性チェック
- ✅ **権限最小化**: 必要最小限の権限での実行
- ✅ **CI/CDセキュリティ**: 自動化されたセキュリティスキャン

### 🔍 自動セキュリティテスト
- **SAST**: ShellCheck による静的解析
- **脆弱性検出**: 危険なパターンの自動検出
- **依存関係チェック**: 外部ツールのセキュリティ監視
- **コンプライアンスチェック**: セキュリティポリシー準拠確認

### ⚡ エラーハンドリング
- ✅ **Fail-safe 設計**: `set -euo pipefail` による厳密なエラー検出
- ✅ **Graceful degradation**: 依存関係欠如時も可能な限り継続実行

### 📋 セキュリティポリシー
- 詳細は [SECURITY.md](SECURITY.md) を参照
- 脆弱性レポートの手順
- セキュリティベストプラクティス

---

## 🚀 CI/CD パイプライン

### 📊 自動化された品質保証

DocKeeperは [DevSecOps ベストプラクティス](https://www.testdevlab.com/blog/integrating-security-testing-into-ci-cd-pipeline)に基づく包括的なCI/CDパイプラインを実装：

| ステージ | 内容 | トリガー |
|---------|------|---------|
| **🔒 セキュリティスキャン** | SAST、脆弱性検出、依存関係チェック | 全プッシュ |
| **🧪 テストスイート** | Unit・Security・Performance テスト | 全プッシュ |
| **🔗 統合テスト** | E2E・構文チェック・動作確認 | PR・main ブランチ |
| **📊 品質ゲート** | 複雑度・ドキュメント・バージョン整合性 | main ブランチ |
| **🛡️ 最終セキュリティ** | 高度なセキュリティスキャン・レポート生成 | main ブランチ |

### 🔄 継続的セキュリティ

- **毎週自動スキャン**: 月曜日 9:00 JST
- **リアルタイム脆弱性検出**: コミット時の即座チェック
- **セキュリティレポート**: 90日間保持のレポート生成
- **自動通知**: Critical 脆弱性発見時の即座アラート

### 📈 パフォーマンス監視

- **ベンチマーク自動実行**: 各プラットフォーム対応
- **パフォーマンス回帰検出**: 閾値ベースの品質管理
- **メトリクス追跡**: 実行時間・メモリ使用量の継続監視

---

## 🧪 テスト戦略

### Unit テスト（推奨）

```bash
# 関数単体テスト
./test_dockeeper.sh

# パフォーマンステスト
./benchmark_dockeeper.sh
```

### 手動テスト手順

```bash
# 1. Dry-run テスト
./dockeeper.sh --dry-run --verbose

# 2. 単一 Cask テスト
brew install --cask firefox  # テスト用アプリ
./dockeeper.sh --dry-run     # 差分確認
brew uninstall --cask firefox

# 3. フル実行テスト（注意: 実際に更新されます）
./dockeeper.sh --verbose
```

---

## 📊 パフォーマンス

| 項目 | 目標値 | 実測値（例） |
|------|--------|-------------|
| **Dock 差分検出** | < 1 秒 | 0.3 秒 |
| **アイコン復元** | < 2 秒/app | 1.1 秒/app |
| **全体実行時間** | < 5 分 | 3.2 分 |
| **メモリ使用量** | < 50 MB | 28 MB |

---

## 🛠️ トラブルシューティング

### よくある問題

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| `dockutil command not found` | dockutil 未インストール | `brew install dockutil` |
| `Permission denied` | 実行権限なし | `chmod +x dockeeper.sh` |
| `Dock items not restored` | Dock キャッシュ問題 | `killall Dock` 手動実行 |

### ログ確認

```bash
# 最新ログ確認
tail -f ~/.local/share/dockeeper/dockeeper.log

# エラーログ抽出
grep "ERROR" ~/.local/share/dockeeper/dockeeper.log
```

### 手動復旧

```bash
```

---

## 🤝 貢献

### 開発ガイドライン

1. **コミット**: [Conventional Commits](https://www.conventionalcommits.org) 準拠
2. **テスト**: 新機能には必ずテストを追加
3. **セキュリティ**: [OWASP Secure Coding](https://owasp.org) 基準遵守
4. **コードスタイル**: Bash best practices 準拠

### PR 要件

- ✅ `shellcheck` 通過
- ✅ Dry-run テスト成功
- ✅ ドキュメント更新
- ✅ セキュリティレビュー

---

## 📜 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

---

## 🔄 更新履歴

### v2.2.0 (2024-12-15)
- 🗑️ **REMOVE**: Dock 状態バックアップ機能を完全削除
- 🧹 **SIMPLIFY**: `--no-backup` オプション削除
- ✨ **FOCUS**: Homebrew Cask 更新とアイコン復元に特化
- 🔧 **FIX**: テストスイートの未定義変数エラー修正
- ⚡ **OPTIMIZE**: スクリプトの軽量化とシンプル化

### v2.1.0 (2024-12-15)
- 🗂️ **STRUCTURE**: dock-keeper サブディレクトリに整理
- 🚀 **MODERNIZE**: brew-cask-upgrade 依存削除、標準 `brew upgrade --cask --greedy` 使用
- 🧹 **SIMPLIFY**: terminal-notifier 削除（ターミナル実行に最適化）
- ⚡ **IMPROVE**: Homebrew 4.0+ バージョンチェック追加
- 📝 **UPDATE**: ドキュメント・テストの更新

### v2.0.0 (2024-12-15)
- ✨ **NEW**: Dry-run モード追加
- ✨ **NEW**: 進捗表示・カラー出力対応
- ✨ **NEW**: 依存関係自動インストール
- ✨ **NEW**: macOS 通知機能
- 🔒 **SECURITY**: 入力検証強化
- 📊 **PERFORMANCE**: パフォーマンス最適化

### v1.0.0 (初期リリース)
- 🎯 **CORE**: 基本的な Dock 復元機能 