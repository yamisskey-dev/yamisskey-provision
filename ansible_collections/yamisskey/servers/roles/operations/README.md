# Operations ロール

システム運用とメンテナンスタスクを実行するAnsibleロール

## 概要

このロールは、デプロイ済みサービスの運用・監視・メンテナンスを統合的に管理します：

### 主要機能

1. **Docker操作管理**
   - コンテナステータス確認
   - サービスの開始・停止・再起動
   - アップデート管理
   - システムクリーンアップ

2. **ヘルスチェック**
   - Docker デーモン監視
   - アプリケーション固有エンドポイント監視
   - カスタムヘルスチェック対応

3. **ログ管理**
   - ログ表示・フィルタリング
   - エラーログ抽出
   - ログエクスポート機能

## 使用方法

### 基本的な実行

```bash
# サービスステータス確認
ansible-playbook -i inventory playbooks/operations.yml

# 特定サービスの状態確認
ansible-playbook -i inventory playbooks/operations.yml -e op=status -e service=misskey

# ヘルスチェック実行
ansible-playbook -i inventory playbooks/operations.yml -e op=health

# ログ確認
ansible-playbook -i inventory playbooks/operations.yml -e op=logs -e service=garage
```

## サポート操作

| 操作 | 説明 | 例 |
|------|------|-----|
| `status` | サービス状態確認 | `-e op=status` |
| `health` | ヘルスチェック実行 | `-e op=health` |
| `logs` | ログ表示 | `-e op=logs` |
| `restart` | サービス再起動 | `-e op=restart` |
| `stop` | サービス停止 | `-e op=stop` |
| `start` | サービス開始 | `-e op=start` |
| `update` | サービス更新 | `-e op=update` |
| `cleanup` | システムクリーンアップ | `-e op=cleanup` |

## パラメータ

### 基本パラメータ

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| `op` | `status` | 実行する操作 |
| `service` | `all` | 対象サービス名 |
| `lines` | `50` | ログ表示行数 |

### ログ管理オプション

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| `log_filter` | なし | ログフィルタキーワード |
| `log_level` | `all` | ログレベル (`error`等) |
| `log_timestamps` | `false` | タイムスタンプ表示 |
| `export_logs` | `false` | ログファイル出力 |

## 対応サービス

- `misskey` - Misskey SNS
- `garage` - オブジェクトストレージ
- `monitor` - Prometheus/Grafana
- `cloudflared` - Cloudflare Tunnel
- `ai` - AI サービス
- `cryptpad` - CryptPad
- `matrix` - Matrix
- `neo-quesdon` - Neo-Quesdon
- `ctfd` - CTFd
- `uptime` - Uptime Kuma
- `minecraft` - Minecraft

## 高度な使用例

### ログ管理

```bash
# エラーログのみ表示
ansible-playbook -i inventory playbooks/operations.yml -e op=logs -e log_level=error

# キーワードでフィルタリング
ansible-playbook -i inventory playbooks/operations.yml -e op=logs -e log_filter="database"

# タイムスタンプ付きログ
ansible-playbook -i inventory playbooks/operations.yml -e op=logs -e log_timestamps=true

# ログをファイルに出力
ansible-playbook -i inventory playbooks/operations.yml -e op=logs -e export_logs=true
```

### サービス管理

```bash
# 特定サービスの再起動
ansible-playbook -i inventory playbooks/operations.yml -e op=restart -e service=misskey

# 全サービスの更新
ansible-playbook -i inventory playbooks/operations.yml -e op=update

# システムクリーンアップ
ansible-playbook -i inventory playbooks/operations.yml -e op=cleanup
```

### タグ使用

```bash
# Docker操作のみ実行
ansible-playbook -i inventory playbooks/operations.yml --tags docker

# ヘルスチェックのみ実行
ansible-playbook -i inventory playbooks/operations.yml --tags health
```

## カスタムヘルスチェック

host_vars または group_vars でカスタムヘルスチェックを定義可能：

```yaml
custom_health_endpoints:
  - service: "my-app"
    port: 8080
    path: "/health"
    method: "GET"
    timeout: 10
```

## 利用可能なタグ

- `docker`: Docker操作関連
- `operations`: 運用操作全般
- `health`: ヘルスチェック
- `monitoring`: 監視関連
- `logs`: ログ管理
- `debugging`: デバッグ関連

## 前提条件

- Docker および Docker Compose がインストール済み
- 各サービスが `/opt/<service_name>` に配置されている
- `docker-compose.yml` ファイルが各サービスディレクトリに存在

## ライセンス

MIT

## 作者情報

yamisskey Development Team
