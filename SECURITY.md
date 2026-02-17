# Security Operations Manual

## 概要

本書は Yamisskey Provision 環境のセキュリティ運用手順を定めるものです。特にシークレット管理、KMS キー回転、災害復旧（DR）について詳細に記載しています。

## 目次

1. [セキュリティアーキテクチャ概要](#セキュリティアーキテクチャ概要)
2. [SOPS 秘密情報管理](#sops-秘密情報管理)
3. [Garage キー管理](#garage-キー管理)
4. [Cloudflare セキュリティ](#cloudflare-セキュリティ)
5. [災害復旧（DR）手順](#災害復旧dr手順)
6. [セキュリティインシデント対応](#セキュリティインシデント対応)
7. [定期メンテナンス](#定期メンテナンス)

---

## セキュリティアーキテクチャ概要

### 多層防御モデル

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Cloudflare (WAF, DDoS Protection, Zero Trust) │
├─────────────────────────────────────────────────────────┤
│ Layer 2: ModSecurity (Application Firewall)            │
├─────────────────────────────────────────────────────────┤
│ Layer 3: UFW (Host-based Firewall)                     │
├─────────────────────────────────────────────────────────┤
│ Layer 4: Encrypted Storage (Garage + Age)               │
├─────────────────────────────────────────────────────────┤
│ Layer 5: Secure Backup (R2 + Filen with encryption)    │
└─────────────────────────────────────────────────────────┘
```

### セキュリティ責任マトリックス

| コンポーネント | 暗号化 | アクセス制御 | バックアップ | モニタリング |
|-------------|-------|-----------|-----------|------------|
| SOPS | ✅ AES256-GCM | 🔐 Age Keys | ✅ Git + 分離保管 | ✅ Commit hooks |
| Garage | ✅ AES256-GCM | 🔐 IAM Policy | ✅ Cross-region | ✅ Audit logs |
| Cloudflare | ✅ TLS 1.3 | 🔐 Zero Trust | ✅ Config backup | ✅ Security events |
| Database | ✅ At-rest + TLS | 🔐 User roles | ✅ Point-in-time | ✅ Query logs |

---

## SOPS 秘密情報管理

### Age キー管理

#### 初期設定

```bash
# 既存の Age 秘密鍵が無い場合は生成
age-keygen -o age-key.txt

# 権限を制限
chmod 600 age-key.txt

# SOPS 用に環境変数を設定（推奨）
export SOPS_AGE_KEY_FILE=$(pwd)/age-key.txt
```

Age 公開鍵は `.sops.yaml` の `keys:` に登録済みです。鍵の追加・入れ替えを行う場合は `.sops.yaml` を更新してコミットしてください。

### シークレット保管場所

- 共通シークレット: `deploy/servers/group_vars/all/secrets.yml`
- ホスト専用シークレット: `deploy/servers/host_vars/<host>/secrets.yml`
- アプライアンス系: `deploy/appliances/group_vars/all/secrets.yml`（必要に応じて作成）

いずれも SOPS で暗号化された YAML です。復号済みの内容はコミットしないでください。

### 編集フロー（make secrets 推奨）

```bash
# グローバルシークレットを編集
make secrets OPERATION=edit TARGET=servers

# balthasar 用シークレットを編集
make secrets OPERATION=edit TARGET=servers HOST=balthasar

# 暗号化状態を検証
make secrets OPERATION=status TARGET=servers HOST=balthasar
```

`HOST` にハイフンを含む場合は自動でアンダースコアに変換されます（例: `HOST=linode-prox` → `host_vars/linode_prox/`）。 `FILE` を指定すると任意の YAML を直接開くことも可能です。

### SOPS 直接操作

`make` を使わない場合は以下を利用します。

```bash
# 復号して閲覧
SOPS_AGE_KEY_FILE=age-key.txt sops -d deploy/servers/group_vars/all/secrets.yml

# 編集
SOPS_AGE_KEY_FILE=age-key.txt sops deploy/servers/host_vars/balthasar/secrets.yml
```

### 鍵ローテーション

**実行頻度**: 6ヶ月に1回、または鍵漏洩時

1. `.sops.yaml` に新しい Age 公開鍵を追加
2. 既存ファイルの受信者を更新

   ```bash
   make secrets OPERATION=updatekeys TARGET=servers
   make secrets OPERATION=updatekeys TARGET=servers HOST=balthasar
   # 必要に応じて appliances も同様に実施
   ```

3. 古い鍵を `.sops.yaml` から削除し、Age 秘密鍵を安全に破棄

4. `make secrets OPERATION=status ...` で復号確認

---

## Garage キー管理

### アーキテクチャ

Garage は S3-compatible object storage として server-side encryption を使用:

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Client    │───▶│    Garage    │───▶│  Encryption │
│ (App/User)  │    │  (Gateway)   │    │    Key      │
└─────────────┘    └──────────────┘    └─────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │   Encrypted  │
                   │   Storage    │
                   └──────────────┘
```

### キー回転手順

**実行頻度**: 3ヶ月に1回、または年次セキュリティレビュー時

#### 1. 事前準備

```bash
# 現在のキー状態確認
garage key list

# バケット一覧とサイズ確認
garage bucket list

# 現在の設定バックアップ
cp /etc/garage.toml garage-config-backup-$(date +%Y%m%d).toml
```

#### 2. 新キー生成

```bash
# 新しいマスターキーを生成（32文字）
NEW_KEY=$(openssl rand -base64 32)
echo "Generated new key: $NEW_KEY"

# SOPS に新キーを追加（例）
make secrets OPERATION=edit TARGET=servers
# garage_secret_key_new: "new-key-here"
```

#### 3. 二重キー許容期間の開始

```bash
# Garage に新キーを追加（既存キーと並行稼働）
garage key create yamisskey-key-v2

# 両キーが利用可能なことを確認
garage key list
```

#### 4. 新キーでの暗号化開始

```bash
# 新しいキーにバケットアクセス権を付与
garage bucket allow --read --write --owner yamisskey-key-v2 --bucket files
garage bucket allow --read --write --owner yamisskey-key-v2 --bucket assets

# 設定確認
garage bucket info files
garage bucket info assets
```

#### 5. 既存データの再暗号化

```bash
# 段階的再暗号化（大容量の場合は分割実行）
# Garage は内部でデータの再バランスを自動管理
# 必要に応じて S3 API 経由でオブジェクトのコピーを実施
```

#### 6. 検証とクリーンアップ

```bash
# データ整合性検証
garage repair --yes blocks

# 新キーでのアクセステスト
curl -I https://drive.yami.ski/files/test-object

# 旧キー無効化（慎重に！）
garage key delete yamisskey-key-v1

# 7日間様子見後、完全削除
```

### キー緊急回転手順（セキュリティインシデント時）

**緊急時**: キー漏洩が疑われる場合の即座対応

```bash
# 1. 既存キーの緊急無効化
garage key delete yamisskey-key-current

# 2. 新キー即座生成・適用
EMERGENCY_KEY=$(openssl rand -base64 32)
garage key create emergency-key-$(date +%Y%m%d)

# 3. バケットアクセス権の再設定
garage bucket allow --read --write --owner emergency-key-$(date +%Y%m%d) --bucket files
garage bucket allow --read --write --owner emergency-key-$(date +%Y%m%d) --bucket assets

# 4. インシデント調査後、通常回転手順で復旧
```

---

## Cloudflare セキュリティ

### API トークン管理

#### トークン回転手順

**実行頻度**: 6ヶ月に1回

```bash
# 1. Cloudflare ダッシュボードで新トークン作成
# - DNS:Edit, Zone:Read permissions
# - Specific zones: yami.ski

# 2. SOPS シークレット更新
make secrets OPERATION=edit TARGET=servers
# cloudflare_api_token: "new-token-here"

# 3. デプロイテスト
yamisskey-provision check cloudflared

# 4. 旧トークン無効化（Cloudflare dashboard）
```

### Tunnel 認証情報管理

#### Tunnel Token 回転

```bash
# 1. 新しいトンネル作成
cloudflared tunnel create yamisskey-balthasar-v2

# 2. 設定ファイル更新
cloudflared tunnel route dns yamisskey-balthasar-v2 yami.ski

# 3. SOPS 変数更新
make secrets OPERATION=edit TARGET=servers

# 4. 段階的切り替え
yamisskey-provision run cloudflared LIMIT=balthasar

# 5. 旧トンネル削除
cloudflared tunnel delete yamisskey-balthasar-v1
```

---

## 災害復旧（DR）手順

### DR シナリオ分類

| シナリオ | 復旧時間目標 (RTO) | データ損失許容 (RPO) | 優先度 |
|---------|------------------|-------------------|-------|
| KMS キー紛失 | 4時間 | 0分 | Critical |
| データベース障害 | 2時間 | 15分 | Critical |
| Garage ストレージ障害 | 6時間 | 1時間 | High |
| 全サーバ障害 | 24時間 | 4時間 | Medium |

### KMS キー災害復旧

#### シナリオ: KMS マスターキーが失われた場合

**影響**: Garage データが復号できず、サービス停止

**復旧手順**:

1. **緊急事態宣言**
   ```bash
   # インシデントチケット作成
   echo "KMS_KEY_LOSS_$(date +%Y%m%d_%H%M)" > /tmp/incident_id

   # 関係者通知（Slack/Teams）
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"🚨 KMS Key Loss Incident - DR procedures initiated"}' \
     $SLACK_WEBHOOK_URL
   ```

2. **Age暗号化バックアップから復旧**
   ```bash
   # 最新のAge暗号化バックアップ確認
   mc ls r2-backup/encrypted-backups/ --recursive | tail -5

   # Age秘密鍵で復号
   mc cp r2-backup/encrypted-backups/latest-garage.age /tmp/
   age --decrypt -i ~/.age/key.txt /tmp/latest-garage.age > /tmp/garage-recovery.toml

   # Garage 設定復元
   cp /tmp/garage-recovery.toml /etc/garage.toml
   ```

3. **Garage サービス復旧**
   ```bash
   # Garage 再起動（設定読み込み）
   yamisskey-provision run garage servers "" restart

   # データアクセステスト
   garage bucket list
   ```

4. **データ整合性検証**
   ```bash
   # ヘルスチェック実行
   garage repair --yes blocks

   # ランダムサンプリング検証
   garage stats
   ```

### データベース災害復旧

#### PostgreSQL Point-in-Time Recovery

```bash
# 1. R2から最新ベースバックアップ取得
mc cp r2-backup/postgres/base-backup-latest.tar.gz /tmp/

# 2. WALファイル同期
mc mirror r2-backup/postgres/wal/ /var/lib/postgresql/wal-restore/

# 3. PostgreSQL復旧開始
sudo systemctl stop postgresql
sudo rm -rf /var/lib/postgresql/14/main/*
sudo tar -xzf /tmp/base-backup-latest.tar.gz -C /var/lib/postgresql/14/main/

# 4. recovery.conf設定
cat > /var/lib/postgresql/14/main/recovery.conf <<EOF
restore_command = 'cp /var/lib/postgresql/wal-restore/%f %p'
recovery_target_time = '2024-01-15 14:00:00 JST'
EOF

# 5. PostgreSQL 起動・復旧完了待ち
sudo systemctl start postgresql
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
```

### 全環境再構築手順

#### Complete Infrastructure Recovery

```bash
# 1. Emergency Kit から認証情報復元
gpg --decrypt emergency-kit.gpg > emergency-credentials.json

# 2. 基本インフラ再構築
yamisskey-provision run system-init servers all
yamisskey-provision run security servers all

# 3. ストレージ復旧
yamisskey-provision run garage appliances

# 4. アプリケーション復旧
yamisskey-provision run misskey
yamisskey-provision run monitor

# 5. 外部接続復旧
yamisskey-provision run cloudflared
yamisskey-provision run modsecurity-nginx
```

---

## セキュリティインシデント対応

### インシデント分類

| レベル | 定義 | 対応時間 | エスカレーション |
|-------|------|---------|----------------|
| P0-Critical | データ漏洩、サービス完全停止 | 15分以内 | 即座に全チーム |
| P1-High | 部分的データアクセス異常 | 1時間以内 | セキュリティチーム |
| P2-Medium | 異常ログ検出、軽微な脆弱性 | 4時間以内 | 運用チーム |

### 緊急連絡先

```yaml
# 緊急連絡リスト（平文で保管、定期更新）
emergency_contacts:
  primary_admin:
    name: "Main Administrator"
    phone: "+81-90-XXXX-XXXX"
    email: "admin@yami.ski"
    signal: "@admin_signal"

  security_team:
    name: "Security Response Team"
    phone: "+81-90-YYYY-YYYY"
    email: "security@yami.ski"

  vendor_support:
    cloudflare: "enterprise-support@cloudflare.com"
    linode: "+1-855-4-LINODE"
```

---

## 定期メンテナンス

### セキュリティメンテナンススケジュール

| タスク | 頻度 | 実行時期 | 責任者 |
|--------|------|----------|--------|
| SOPS 鍵回転 | 6ヶ月 | 6月/12月 | Admin |
| Garage キー回転 | 3ヶ月 | 四半期末 | Admin |
| TLS証明書更新 | 自動 | Let's Encrypt | System |
| セキュリティパッチ適用 | 週次 | 日曜深夜 | Unattended |
| 脆弱性スキャン | 月次 | 月初 | Security |
| DRテスト実行 | 6ヶ月 | 3月/9月 | Team |

### 月次セキュリティレビュー

```bash
#!/bin/bash
# monthly-security-review.sh

echo "=== Monthly Security Review $(date +%Y-%m) ==="

# 1. アクセスログ異常検知
echo "1. Analyzing access logs..."
zcat /var/log/nginx/access.log.*.gz | \
  awk '{print $1}' | sort | uniq -c | sort -nr | head -20

# 2. 失敗ログイン試行
echo "2. Failed authentication attempts..."
sudo grep "Failed password" /var/log/auth.log | wc -l

# 3. SOPS ファイル整合性チェック
echo "3. SOPS integrity check..."
SOPS_AGE_KEY_FILE=age-key.txt sops -d deploy/servers/group_vars/all/secrets.yml >/dev/null && echo "✅ SOPS OK"

# 4. Garage 健全性
echo "4. Garage health..."
garage stats

# 5. バックアップ検証
echo "5. Backup verification..."
mc ls r2-backup/ | tail -5

echo "=== Review completed ==="
```

---

## Emergency Kit (緊急時パッケージ)

### 構成内容

```
emergency-kit/
├── credentials/
│   ├── ssh-keys/              # SSH秘密鍵（パスフレーズ保護）
│   ├── age-keys/              # Age暗号化鍵（SOPS用）
│   └── recovery-tokens        # 各種API トークン
├── procedures/
│   ├── quick-start.md         # 緊急時クイックスタート
│   ├── contact-list.md        # 連絡先一覧
│   └── escalation-tree.png    # エスカレーション体系図
├── backups/
│   ├── config-snapshots/      # 設定ファイルスナップショット
│   └── minimal-inventory/     # 最小インベントリファイル
└── tools/
    ├── verify-integrity.sh    # 整合性確認スクリプト
    └── emergency-restore.sh   # 緊急復旧スクリプト
```

### Emergency Kit 更新手順

```bash
# 1. キット内容更新（月次）
./scripts/update-emergency-kit.sh

# 2. GPG暗号化
tar czf emergency-kit-$(date +%Y%m%d).tar.gz emergency-kit/
gpg --armor --cipher-algo AES256 --compress-algo 2 \
  --symmetric emergency-kit-*.tar.gz

# 3. オフライン保管場所へ分散保管
# - 物理USBメモリ（防火金庫）
# - クラウドストレージ（別アカウント）
# - 信頼できる第三者保管
```

---

## 付録

### A. コマンドリファレンス

```bash
# よく使用するセキュリティコマンド
SOPS_AGE_KEY_FILE=age-key.txt sops -d deploy/servers/group_vars/all/secrets.yml
SOPS_AGE_KEY_FILE=age-key.txt sops deploy/servers/host_vars/balthasar/secrets.yml
make secrets OPERATION=updatekeys TARGET=servers
garage key list
garage repair --yes blocks
age --encrypt -R ~/.age/public-key.txt < secrets.txt > secrets.age
age --decrypt -i ~/.age/key.txt secrets.age
```

### B. 監査ログ形式

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "event_type": "kms_key_rotation",
  "severity": "info",
  "actor": "admin@yami.ski",
  "resource": "garage/yamisskey-key-v1",
  "action": "rotate",
  "result": "success",
  "metadata": {
    "old_key_id": "yamisskey-key-v1",
    "new_key_id": "yamisskey-key-v2",
    "rotation_reason": "scheduled_maintenance"
  }
}
```

### C. セキュリティ設定チェックリスト

- [ ] SOPS Age 秘密鍵の保護（オフライン複製 + アクセス制御）
- [ ] Garage キー定期回転（3ヶ月以内）
- [ ] TLS 証明書有効期限（30日以上残存）
- [ ] バックアップ暗号化検証（週次）
- [ ] アクセスログ異常監視（日次）
- [ ] Emergency Kit 更新（月次）

---

**文書管理**
- 作成日: 2024-01-15
- 最終更新: 2024-01-15
- バージョン: 1.0
- 次回レビュー: 2024-04-15
