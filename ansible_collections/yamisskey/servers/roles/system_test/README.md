# System Test ロール

システムテストとインフラストラクチャ検証を行うAnsibleロール

## 概要

このロールは、システムの健全性を包括的にテストし、以下の項目を検証します：

### インフラストラクチャテスト
- Inventoryファイルの存在確認
- Tailscale VPNの可用性
- Ansible環境の可用性
- Docker環境の可用性

### 移行システムテスト
- 移行ロールの構造確認
- 非同期処理・進捗監視機能の確認

### サービスヘルステスト
- 各種サービスエンドポイントの疎通確認
- サービス固有のヘルスチェック

## 必要条件

- システムが初期化済みであること
- テスト対象サービスが起動していること（サービステストのみ）

## ロール変数

### デフォルト変数 (defaults/main.yml)

#### テスト制御変数
| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `run_infrastructure_tests` | `true` | インフラテストを実行するかどうか |
| `run_migration_tests` | `true` | 移行システムテストを実行するかどうか |
| `run_service_tests` | `true` | サービステストを実行するかどうか |
| `fail_on_critical_errors` | `true` | 重要なテストが失敗した場合に停止するかどうか |

#### テスト対象ツール
```yaml
required_tools:
  - ansible
  - docker
  - git

optional_tools:
  - tailscale
  - cloudflared
  - warp-cli
```

#### サービスエンドポイント設定
```yaml
service_endpoints:
  - { port: "3900", path: "/health", name: "Garage", required: false }
  - { port: "3000", path: "/api/ping", name: "Misskey", required: false }
  - { port: "9090", path: "/-/healthy", name: "Prometheus", required: false }
  - { port: "3000", path: "/api/health", name: "Grafana", required: false }
```

### ホスト変数の要件

サービステストを実行する場合、以下の変数が必要です：

```yaml
host_services:
  hostname:
    garage_api: 3900
    misskey: 3000
    prometheus: 9090
    grafana: 3000
```

## 使用例

### 基本的な使用方法

```yaml
- hosts: all
  roles:
    - yamisskey.servers.system-test
```

### 選択的テスト実行

```yaml
- hosts: all
  roles:
    - role: yamisskey.servers.system-test
      vars:
        run_service_tests: false
        fail_on_critical_errors: false
```

### タグを使用した部分実行

```bash
# インフラテストのみ実行
ansible-playbook -i inventory playbook.yml --tags infrastructure

# 移行システムテストのみ実行
ansible-playbook -i inventory playbook.yml --tags migration

# サービステストのみ実行
ansible-playbook -i inventory playbook.yml --tags services
```

## 利用可能なタグ

- `infrastructure`: インフラストラクチャテスト
- `migration`: 移行システムテスト
- `services`: サービスヘルステスト
- `always`: 常に実行されるタスク

## テスト結果の解釈

### スコア計算
- 全体スコア = 合格テスト数 / 総テスト数
- 80%以上: 本番環境対応可能
- 50-79%: 一部問題があるが機能的
- 50%未満: 重要な問題がある

### 結果表示記号
- ✅ = 合格
- ⚠️ = 警告（非必須項目の不具合）
- ❌ = 失敗（必須項目の不具合）

## テスト項目詳細

### Test 1: Inventory存在確認
Ansibleインベントリファイルの存在を確認

### Test 2: Tailscale可用性
Tailscale VPNクライアントのインストール状態を確認

### Test 3: Ansible可用性
Ansibleコマンドの実行可能性とバージョンを確認

### Test 4: Docker可用性
Dockerデーモンの実行状態とバージョンを確認

### Test 5: 移行ロール構造
移行用ロールのディレクトリ構造とタスクファイルの存在を確認

### Test 6: 進捗監視機能
移行処理での非同期実行・ポーリング機能の設定を確認

### Test 7: サービスヘルス
設定されたサービスエンドポイントの疎通確認

## ライセンス

MIT

## 作者情報

yamisskey Development Team
