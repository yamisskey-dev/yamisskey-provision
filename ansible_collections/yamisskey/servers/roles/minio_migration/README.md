# yamisskey.servers.minio_migration

統合されたMinIO移行ロール - タグベースの柔軟な実行制御

## 概要

このロールは、既存の3つのMinIO移行関連ロール（`migrate`、`migrate_minio`、`migration_validator`）を統合し、タグベースの実行制御により柔軟な移行プロセスを提供します。

## 統合された機能

### 元のロールから統合された機能:
- **migrate**: メインの移行処理、MinIO CLI設定、データ転送
- **migrate_minio**: 暗号化検証、API アクセステスト、設定ガイダンス
- **migration_validator**: 事前・事後検証、詳細なパラメータ・接続・容量チェック

### 新機能:
- 🏷️ **タグベースの実行制御**: 必要なフェーズのみ実行可能
- 📊 **統合レポート生成**: 各フェーズの詳細レポート
- 🔄 **柔軟なフェーズ制御**: 設定ファイルでフェーズのON/OFF
- 🛡️ **強化された検証**: 複数レベルの検証機能
- 📈 **進捗監視**: リアルタイム進捗表示

## 実行フェーズ

| フェーズ | タグ | 説明 |
|---------|-----|------|
| Setup | `setup` | MinIO CLIインストール・設定 |
| Validation | `validate` | 事前検証（パラメータ、接続、容量など） |
| Migration | `migrate` | 実際のデータ移行 |
| Verification | `verify` | 事後検証（整合性、API アクセステスト） |
| Cleanup | `cleanup` | 一時ファイル削除 |
| All | `all` | 全フェーズ実行 |

## 要件

- Ansible >= 2.9
- Python >= 3.6
- Docker（Molecule テスト用）

## インストール

```bash
# リポジトリをクローン（既にあるプロジェクトの一部として）
git clone https://github.com/yamisskey-dev/yamisskey-provision.git
cd yamisskey-provision
```

## 使用方法

### 基本的な使用例

#### 1. 全フェーズ実行（従来の移行）
```bash
ansible-playbook -i inventory playbook.yml \
  -e "migrate_source=balthasar migrate_target=raspberrypi" \
  --limit raspberrypi \
  --tags all
```

#### 2. フェーズ別実行

```bash
# セットアップのみ
ansible-playbook playbook.yml --tags setup

# 事前検証のみ
ansible-playbook playbook.yml --tags validate

# 実際の移行のみ（事前にsetup必須）
ansible-playbook playbook.yml --tags migrate

# 事後検証のみ
ansible-playbook playbook.yml --tags verify

# クリーンアップのみ
ansible-playbook playbook.yml --tags cleanup
```

#### 3. 複数フェーズの組み合わせ
```bash
# セットアップ + 検証
ansible-playbook playbook.yml --tags setup,validate

# 移行 + 検証
ansible-playbook playbook.yml --tags migrate,verify
```

### 詳細な使用例

#### raspberrypi から balthasar への移行
```bash
ansible-playbook -i deploy/servers/inventory \
  deploy/servers/playbooks/migrate-minio.yml \
  -e "migrate_source=raspberrypi migrate_target=balthasar" \
  -e "source_minio_port=9000 target_minio_port=9000" \
  --limit balthasar \
  --ask-become-pass
```

#### 段階的移行（推奨）
```bash
# 1. 事前検証
ansible-playbook playbook.yml --tags setup,validate

# 2. 移行実行（検証結果に問題がなければ）
ansible-playbook playbook.yml --tags migrate

# 3. 事後検証
ansible-playbook playbook.yml --tags verify

# 4. クリーンアップ
ansible-playbook playbook.yml --tags cleanup
```

## 設定

### 必須変数

```yaml
# ソースMinIO設定
migrate_source: "balthasar"
source_minio_port: 9000

# ターゲットMinIO設定
migrate_target: "raspberrypi"
target_minio_port: 9000

# 移行するバケット
buckets_to_migrate:
  - "files"
  - "assets"
```

### 重要な設定オプション

```yaml
# フェーズ制御
minio_migration_phases:
  setup: true
  validate: true
  migrate: true
  verify: true
  cleanup: true

# 検証設定
validate_parameters: true
validate_connectivity: true
validate_services: true
validate_capacity: true
validate_integrity: true

# 暗号化設定
enable_encryption: true
kms_enabled: true

# レポート生成
generate_validation_report: true
generate_migration_report: true
save_report_to_file: true
```

### 高度な設定

```yaml
# パフォーマンス設定
migration_timeout: 3600
migration_parallel_transfers: 4
migration_bandwidth_limit: "100MiB"

# 安全性設定
require_confirmation: true
backup_before_migration: true
fail_on_validation_error: true

# デバッグ設定
debug_mode: false
verbose_logging: false
```

## プレイブック例

### migrate-minio.yml
```yaml
---
- name: MinIO Migration
  hosts: "{{ migrate_target }}"
  become: true
  gather_facts: true

  roles:
    - role: yamisskey.servers.minio_migration
      vars:
        migrate_source: "{{ migrate_source }}"
        migrate_target: "{{ migrate_target }}"
        buckets_to_migrate:
          - "{{ minio_bucket_name_for_misskey }}"
```

## 移行プロセス

### 1. 事前準備
- [ ] ソース・ターゲットMinIOが稼働中
- [ ] 認証情報が正しく設定済み
- [ ] 十分なディスク容量が確保済み
- [ ] ネットワーク接続が確立済み

### 2. 事前検証 (`--tags validate`)
- [ ] パラメータ検証
- [ ] 接続性確認
- [ ] サービス状態確認
- [ ] ストレージ容量確認
- [ ] 移行準備状況評価

### 3. データ移行 (`--tags migrate`)
- [ ] MinIO CLI設定
- [ ] ソースからの一時ダウンロード
- [ ] ターゲットへの暗号化アップロード
- [ ] ファイル数検証
- [ ] 一時ファイルクリーンアップ

### 4. 事後検証 (`--tags verify`)
- [ ] ファイル数整合性確認
- [ ] 暗号化状態確認
- [ ] API アクセステスト
- [ ] サービス健全性確認

### 5. 後処理
- [ ] アプリケーション設定更新
- [ ] DNS設定更新（必要に応じて）
- [ ] ソースMinIO停止（テスト後）

## トラブルシューティング

### よくある問題

#### 1. 接続エラー
```
❌ Failed to connect to source MinIO
```
**解決策:**
- MinIOサービスが稼働中か確認
- ポート番号が正しいか確認
- ファイアウォール設定確認

#### 2. 認証エラー
```
❌ Failed to list source MinIO buckets
```
**解決策:**
- `host_vars/*/secrets.yml`の認証情報確認
- MinIOユーザー権限確認

#### 3. 容量不足
```
❌ Insufficient disk space for migration
```
**解決策:**
- `/tmp`ディスクの空き容量確認
- `migration_temp_dir`を変更

#### 4. ファイル数不一致
```
❌ Migration verification failed
```
**解決策:**
- 移行ログ確認
- ネットワーク状態確認
- 再実行を検討

### ログ確認

```bash
# 移行ログ
tail -f /tmp/minio-migration/migration.log

# Ansibleログ
ansible-playbook playbook.yml -v
```

### デバッグモード

```bash
ansible-playbook playbook.yml \
  -e "debug_mode=true verbose_logging=true" \
  --tags validate
```

## 開発・テスト

### Molecule テスト

```bash
# テスト実行
cd ansible_collections/yamisskey/servers/roles/minio_migration
molecule test

# 個別テスト
molecule converge
molecule verify
molecule destroy
```

### 貢献

1. フォークを作成
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## ライセンス

MIT License - 詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 更新履歴

### v1.0.0 (2024-01-01)
- 初回リリース
- 3つのロール（migrate, migrate_minio, migration_validator）を統合
- タグベースの実行制御を実装
- 包括的な検証・レポート機能を追加

## サポート

- Issues: https://github.com/yamisskey-dev/yamisskey-provision/issues
- Discussions: https://github.com/yamisskey-dev/yamisskey-provision/discussions

---

## 従来のロールからの移行

既存の`migrate`、`migrate_minio`、`migration_validator`ロールを使用している場合：

### 1. 設定の互換性
既存の変数名はほぼそのまま使用可能です：
```yaml
# 既存の設定がそのまま動作
migrate_source: "balthasar"
migrate_target: "raspberrypi"
minio_bucket_name_for_misskey: "files"
```

### 2. プレイブックの更新
```yaml
# 変更前
- role: yamisskey.servers.migrate
- role: yamisskey.servers.migrate_minio
- role: yamisskey.servers.migration_validator

# 変更後（統合ロール）
- role: yamisskey.servers.minio_migration
```

### 3. 段階的移行
1. 新しいロールをテスト環境で試行
2. 本番環境での移行前に十分な検証実施
3. 既存のロールは廃止予定のため新しいロールへ移行推奨
