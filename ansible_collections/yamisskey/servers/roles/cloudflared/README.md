# yamisskey.servers role: cloudflared

Garage用のCloudflare Tunnel設定を管理するAnsibleロールです。

## 概要

このロールは以下を実行します：

1. **設定ファイルの作成** - `config.yml.j2`Jinjaテンプレートを使用
2. **Garage用ルーティング** - drive.yami.ski → Nginx(8080) → Garage(3900)

## 重要な注意点

**インストールとサービス設定は含まれません**
プロジェクトルートの[README.md](../../../README.md)の手順に従って手動で実行してください。

## 使用方法

### 1. 統一コマンドでの実行

```bash
# Cloudflaredプレイブック実行
make run PLAYBOOK=cloudflared

# ドライラン（変更内容確認）
make check PLAYBOOK=cloudflared

# 特定のタグのみ実行
make run PLAYBOOK=cloudflared TAGS=config
```

### 2. 手動セットアップ（プロジェクトREADME.md準拠）

```bash
# Ansibleインストール
make install

# インベントリ作成
make inventory

# ログインと認証
cloudflared tunnel login

# トンネル作成
cloudflared tunnel create raspberrypi-garage
cloudflared tunnel route dns raspberrypi-garage drive.yami.ski

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
Internet → Cloudflare → Cloudflared → Nginx(8080) → Garage(3900)
```

### 生成されるファイル
- `/home/taka/.cloudflared/config.yml` - Cloudflared設定ファイル

### Garage設定
- **ホスト名**: `drive.yami.ski`
- **プロキシ先**: `http://localhost:8080` (Nginx)
- **最終宛先**: Garage (localhost:3900)

## Misskeyオブジェクトストレージ設定

```
参照URL: https://drive.yami.ski/files
バケット名: files
エンドポイント: drive.yami.ski
リージョン: ap-northeast-3
```

## 依存関係

- **Garageロール**: Garageサービスが動作中
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
