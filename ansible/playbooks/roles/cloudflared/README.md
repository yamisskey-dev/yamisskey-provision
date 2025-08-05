# Cloudflared Role

MinIO用のCloudflare Tunnel設定を管理するAnsibleロールです。

## 概要

このロールは以下を実行します：

1. **設定ファイルの作成** - `config.yml.j2`Jinjaテンプレートを使用
2. **MinIO用ルーティング** - drive.yami.ski → Nginx(8080) → MinIO(9000)

## 重要な注意点

**インストールとサービス設定は含まれません**  
プロジェクトルートの[README.md](../../../README.md)の手順に従って手動で実行してください。

## 使用方法

### 1. 通常のプロビジョニング実行

```bash
make provision  # cloudflaredロールがMinIOプロビジョニングに自動的に含まれる
```

### 2. 手動セットアップ（プロジェクトREADME.md準拠）

```bash
# インストール
make install

# ログインと認証
cloudflared tunnel login

# トンネル作成
cloudflared tunnel create yaminio
cloudflared tunnel route dns yaminio drive.yami.ski

# 設定ファイル更新
# /home/taka/.cloudflared/config.yml の <Tunnel-UUID> を実際の値に変更

# systemd設定
sudo mkdir -p /etc/cloudflared
sudo cp /home/taka/.cloudflared/config.yml /etc/cloudflared/
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

## 設定内容

### アーキテクチャ
```
Internet → Cloudflare → Cloudflared → Nginx(8080) → MinIO(9000)
```

### 生成されるファイル
- `/home/taka/.cloudflared/config.yml` - Cloudflared設定ファイル

### MinIO設定
- **ホスト名**: `drive.yami.ski`
- **プロキシ先**: `http://localhost:8080` (Nginx)
- **最終宛先**: MinIO (localhost:9000)

## Misskeyオブジェクトストレージ設定

```
参照URL: https://drive.yami.ski/files
バケット名: files
エンドポイント: drive.yami.ski
リージョン: ap-northeast-3
```

## 依存関係

- **MinIOロール**: MinIOサービスが動作中
- **ModSecurity-Nginxロール**: Nginxプロキシが設定済み
- **make install**: Cloudflaredバイナリインストール済み

## トラブルシューティング

```bash
# サービス状態確認
sudo systemctl status cloudflared

# ログ確認
sudo journalctl -u cloudflared -f

# 設定確認
sudo cat /etc/cloudflared/config.yml