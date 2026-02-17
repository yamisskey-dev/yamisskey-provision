# CI/CD Workflows

このディレクトリには、yamisskey-provisionプロジェクトの自動化ワークフローが含まれています。

## 📋 ワークフロー一覧

### 🔍 品質管理ワークフロー (分離型)

#### 🔍 **Code Quality (Lint)** (`lint.yml`)
- **トリガー**: Pull Request、mainブランチへのpush
- **目的**: コード品質とスタイルの統一
- **実行内容**:
  - YAML Lint (yamllint)
  - Ansible Lint (ansible-lint) - 並列実行
  - Ansible Sanity Tests (ansible-test sanity)
  - Collections構造検証

#### 📋 **Syntax Check** (`syntax.yml`)
- **トリガー**: Pull Request、mainブランチへのpush
- **目的**: Ansible構文の検証
- **実行内容**:
  - Servers/Appliances プレイブックの構文チェック
  - 並列実行による高速化

#### 🔐 **Security Scan** (`security.yml`)
- **トリガー**: Pull Request、mainブランチへのpush
- **目的**: セキュリティ脆弱性の検出
- **実行内容**:
  - Trivy設定スキャン (misconfig, secret)
  - AGE秘密鍵の検出
  - その他機密情報パターンチェック
  - 依存関係脆弱性チェック

#### 🔄 **Idempotency Tests** (`idempotency.yml`)
- **トリガー**: Pull Request、mainブランチへのpush
- **目的**: Ansibleプレイブックのべき等性検証
- **実行内容**:
  - `--check --diff`モードでのドライラン
  - Servers: Core Infrastructure + Application Stack
  - Appliances: TrueNAS Setup
  - 並列実行とアーティファクト共有

### ⚛ **テスティングワークフロー**

#### 📋 **Role-Specific Molecule Tests** (`molecule-tests.yml`)
- **トリガー**: Role変更時の自動検出 (PR/push)
- **目的**: 変更されたロールの効率的テスト
- **実行内容**:
  - 変更検出による動的テスト対象選択
  - ロール単位でのMoleculeテスト実行
  - 高速フィードバックループ

#### 🧪 **Full Test Suite** (`molecule-full-suite.yml`)
- **トリガー**: mainブランチpush、スケジュール実行 (毎晩2時JST)、手動実行
- **目的**: 包括的な品質保証とパフォーマンス分析
- **実行内容**:
  - **Full Test Suite**: 全コレクション横断テスト
  - **Comprehensive Validation**: 構造・依存関係・互換性検証
  - **Performance Analysis**: プレイブック・ロール複雑性分析
  - **Scheduled Deep Testing**: 定期的な品質監査

### 🚀 **リリース管理**
- **Collections Release** (`release-collections.yml`): Ansibleコレクションリリース
- **General Release** (`release.yml`): プロジェクト全体のリリース

## 🔧 新しいワークフロー設計の利点

### 🚀 **パフォーマンス向上**
- **並列実行**: 各ワークフローが独立して実行
- **早期フィードバック**: Lint/Syntaxが先に完了
- **失敗高速検出**: 問題カテゴリーの即時特定

### 🎯 **責務分離**
- **Lint**: コード品質 (yamllint, ansible-lint, sanity)
- **Syntax**: 構文正確性 (playbook syntax-check)
- **Security**: セキュリティ (Trivy, secret detection)
- **Idempotency**: 運用信頼性 (--check --diff tests)

### 🐛 **デバッグ効率化**
- **問題特定の高速化**: カテゴリー別の明確な分離
- **部分的再実行**: 特定領域のみの修正・テスト
- **ログ分散**: 各ワークフローで独立したログ

## 📊 ワークフロー詳細

### 🔍 Lint Workflow

#### ジョブ構成
1. **yaml-lint**: YAML構文・スタイルチェック
2. **ansible-lint**: Ansibleベストプラクティス検証 (servers/appliances並列)
3. **ansible-test-sanity**: Ansibleコレクション内部検証
4. **verify-structure**: ディレクトリ構造確認

#### 特徴
- **マトリックス戦略**: servers/appliancesの並列処理
- **外部Collection**: 自動インストール・キャッシュ
- **非ブロッキング**: 一部警告は許可

### 📋 Syntax Workflow

#### ジョブ構成
- **syntax-check**: 全プレイブックの構文検証
- **マトリックス**: servers/appliances並列実行

#### 実行範囲
- `deploy/servers/playbooks/*.yml`
- `deploy/appliances/playbooks/*.yml`

### 🔐 Security Workflow

#### ジョブ構成
1. **trivy-scan**: インフラ設定の脆弱性スキャン
2. **secret-scan**: 機密情報の誤コミット検出
3. **dependency-check**: 依存関係セキュリティチェック

#### 検出対象
- **設定ミス**: Trivy misconfig
- **機密情報**: AGE keys, API keys, passwords, certificates
- **脆弱性**: Python/Ansible依存関係

### 🔄 Idempotency Workflow

#### ジョブ構成
1. **prepare-inventory**: テスト用インベントリ作成・共有
2. **servers-core-infrastructure**: [common, security, system-init]
3. **servers-application-stack**: [misskey, garage, monitor]
4. **appliances-truenas**: [setup, migrate-garage-truenas]

#### テスト戦略
- **ドライラン**: `--check --diff`での安全な検証
- **並列実行**: プレイブック単位でのマトリックス
- **アーティファクト共有**: インベントリファイルの効率的再利用

## ⚙️ 設定・トリガー

### 共通トリガー
```yaml
on:
  pull_request:
    branches: ["**"]
  push:
    branches: [main]
```

### 並行性制御
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## 🔧 ローカル開発

### 事前実行推奨 (カテゴリー別)
```bash
# Lint
yamllint .
ansible-lint ansible_collections/yamisskey/servers
ansible-lint ansible_collections/yamisskey/appliances

# Syntax
ansible-playbook --syntax-check deploy/servers/playbooks/*.yml
ansible-playbook --syntax-check deploy/appliances/playbooks/*.yml

# Security (手動確認)
grep -r "AGE-SECRET-KEY" . --exclude-dir=.git

# Idempotency (例)
ansible-playbook -i inventory playbooks/common.yml --check --diff
```

## 📈 CI/CD メトリクス

### 品質指標
- **Lint通過率**: 100%目標
- **Security問題**: 0件 (CRITICAL/HIGH)
- **Syntax エラー**: 0件
- **Idempotency**: 全プレイブック通過

### パフォーマンス目標
- **Lint**: 3分以内
- **Syntax**: 2分以内
- **Security**: 5分以内
- **Idempotency**: 8分以内

## 🔄 マイグレーション情報

### 変更点
- **責務分離**: 明確なカテゴリー別実行
- **並列化強化**: matrix strategyの活用拡大

### 互換性
- **既存機能**: 全て新ワークフローで継承
- **追加機能**: セキュリティスキャンの拡充
- **設定**: トリガー条件・環境変数は維持

## 🐛 トラブルシューティング

### カテゴリー別デバッグ

#### Lint 失敗
```bash
# ローカル再現
yamllint .github ansible_collections deploy
ansible-lint --offline -v ansible_collections/yamisskey/servers
```

#### Syntax 失敗
```bash
# 個別チェック
ansible-playbook -i localhost, -c local deploy/servers/playbooks/common.yml --syntax-check
```

#### Security 失敗
```bash
# 機密情報チェック
grep -rEi "password\s*=\s*['\"][^'\"]{8,}['\"]" . --exclude-dir=.git
```

#### Idempotency 失敗
```bash
# ローカル --check
ansible-playbook -i inventory playbook.yml --check --diff -e ansible_become=false
```

## 🔗 関連ドキュメント

- [**GitHub Actions**](https://docs.github.com/en/actions) - ワークフロー仕様
- [**Ansible Lint**](https://ansible-lint.readthedocs.io/) - リンティングルール
- [**Trivy**](https://trivy.dev/) - セキュリティスキャナー
- [**プロジェクト概要**](../README.md) - 全体アーキテクチャ

## 📋 今後の改善計画

### 次期機能
- **依存関係グラフ**: ワークフロー間の依存関係可視化
- **キャッシュ最適化**: 共通依存関係の効率的共有
- **通知統合**: Slack/Discord/Teams連携
- **品質ゲート**: 品質スコアによる自動判定

### 監視・分析
- **実行時間分析**: ボトルネック特定・最適化
- **成功率追跡**: 品質トレンド監視
- **リソース使用量**: コスト効率化
