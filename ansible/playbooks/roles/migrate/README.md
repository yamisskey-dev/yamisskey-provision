# MinIO Migration Guide

## 概要

このガイドでは、balthasar から raspberrypi への MinIO データ移行プロセスについて説明します。
完全に自動化されたシステムで、Tailscale ネットワーク経由での安全な移行を実現します。

## 前提条件

### 1. ネットワーク設定
- 両ホストが Tailscale ネットワークに接続済み
- SSH 接続が可能
- MinIO サービスが両ホストで稼働中

### 2. 必要なファイル
- `/opt/yamisskey-provision/secrets.yml` が両ホストに存在
- 有効な MinIO 認証情報が設定済み

### 3. システム要件
- Ansible 実行環境
- 十分なディスク容量（移行データの 2倍以上推奨）

## 移行手順

### Step 1: 基本的な移行（推奨）

```bash
# 動的インベントリを生成して移行実行
make migrate SOURCE=balthasar TARGET=raspberrypi
```

このコマンドは以下を自動実行します：
1. Tailscale IP アドレスの自動検出
2. 動的インベントリファイルの生成
3. SSH 接続の確認
4. MinIO データの移行
5. 暗号化の確認

### Step 2: 手動での詳細実行

```bash
# 1. インベントリ生成
make inventory SOURCE=balthasar TARGET=raspberrypi

# 2. 接続確認
ansible -i ansible/inventory all -m ping

# 3. 移行実行
ansible-playbook -i ansible/inventory \
  ansible/playbooks/migrate.yml \
  -e "migrate_source=balthasar migrate_target=raspberrypi" \
  --limit raspberrypi --ask-become-pass
```

### Step 3: カスタムポート設定

```bash
# カスタムポートでの移行
make inventory SOURCE=balthasar TARGET=raspberrypi
ansible-playbook -i ansible/inventory \
  ansible/playbooks/migrate.yml \
  -e "migrate_source=balthasar migrate_target=raspberrypi" \
  -e "source_minio_port=9001 target_minio_port=9002" \
  --limit raspberrypi --ask-become-pass
```

## 移行プロセスの詳細

### Phase 1: 事前確認
- ホスト接続性の確認
- MinIO サービス状態の確認
- 認証情報の検証
- ディスク容量の確認

### Phase 2: データ移行
- MinIO CLI の自動インストール
- 一時エイリアスの設定
- バケット毎の並列データ移行
- プログレス追跡

### Phase 3: 検証
- ファイル数の比較
- データ整合性の確認
- 暗号化状態の検証
- アクセス権限の確認

### Phase 4: 後処理
- 一時ファイルの削除
- エイリアスのクリーンアップ
- 移行ログの生成
- 次ステップの案内

## 移行されるデータ

### 対象バケット
- `files` - Misskey のメディアファイル
- `assets` - Outline のアセット

### データ保護機能
- 転送中の暗号化（TLS）
- 保存時の暗号化（KMS）
- データ整合性の確認
- 自動バックアップ作成

## トラブルシューティング

### ネットワーク接続エラー
```bash
# Tailscale 状態確認
sudo tailscale status

# SSH 接続テスト
ssh user@balthasar.tail-scale.ts.net "echo 'SSH OK'"
```

### MinIO 接続エラー
```bash
# MinIO サービス状態確認
sudo systemctl status minio

# ポート確認
sudo netstat -tlnp | grep 9000
```

### 認証情報エラー
```bash
# secrets.yml の確認
sudo cat /opt/yamisskey-provision/secrets.yml | grep minio
```

### ディスク容量不足
```bash
# ディスク使用量確認
df -h /opt/minio
df -h /tmp

# MinIO データサイズ確認
sudo du -sh /opt/minio/minio-data/*
```

## 移行後の確認事項

### 1. データ確認
```bash
# ファイル数の確認
sudo docker exec minio mc ls --recursive minio/files/ | wc -l
sudo docker exec minio mc ls --recursive minio/assets/ | wc -l
```

### 2. アプリケーション設定更新
- Misskey の S3 設定更新
- Outline の S3 設定更新
- DNS 設定の更新（drive.yami.ski）

### 3. 動作確認
- ファイルアップロードテスト
- 画像表示確認
- 連合機能での画像表示確認

## 緊急時のロールバック

### データ復元手順
```bash
# 逆方向移行（raspberrypi → balthasar）
make migrate SOURCE=raspberrypi TARGET=balthasar

# DNS 設定の復元
# drive.yami.ski → balthasar IP

# アプリケーション設定の復元
# 各アプリの S3 設定を balthasar に戻す
```

## セキュリティ考慮事項

### データ保護
- 全データが KMS 暗号化済み
- Tailscale プライベートネットワーク使用
- SSH 鍵認証必須
- 最小権限の原則

### アクセス制御
- MinIO Web UI 無効化
- CLI 管理のみ
- Nginx プロキシ経由でのアクセス制限
- ActivityPub 対応のセキュリティポリシー

## パフォーマンス最適化

### 移行速度向上
- 並列バケット処理
- 大容量ファイルの分割転送
- ネットワーク帯域幅の最適化

### 暗号化オーバーヘッド
- ハードウェア暗号化の活用
- CPU 使用率の監視
- メモリ使用量の最適化

## モニタリング

### 移行中の監視
```bash
# リアルタイムログ監視
tail -f /tmp/minio-migration/migration.log

# システムリソース監視
top
iotop
```

### 移行後の監視
```bash
# MinIO メトリクス確認
sudo docker exec minio mc admin prometheus generate minio

# アプリケーションログ確認
sudo docker logs misskey
sudo docker logs outline
```

## 最新の更新内容

### v2.0 (Dynamic Inventory System)
- Tailscale ネットワーク完全対応
- 動的ホスト解決システム
- 実用性の大幅向上
- エラーハンドリング強化

### 主な改善点
- 任意ホスト間移行対応
- SSH 接続自動確立
- ネットワーク診断機能
- 移行状況の詳細表示

---

**注意**: 本番環境での移行前に、必ずテスト環境での動作確認を実施してください。