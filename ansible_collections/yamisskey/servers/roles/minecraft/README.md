# yamisskey.servers role: minecraft

このロールは、Java版とBedrock版の両方からアクセス可能なクロスプラットフォームMinecraftサーバーを構築します。

## 概要

- **サーバーソフトウェア**: PaperMC (高性能なSpigotフォーク)
- **クロスプラットフォーム対応**: Geyser + Floodgate
- **コンテナ化**: Docker + Docker Compose
- **管理ツール**: Portainer
- **ネットワーク**: PlayIt (トンネリング) - オプション

## 対応プラットフォーム

### ✅ 完全対応
- **Ubuntu** (20.04, 22.04, 24.04) - x86_64/amd64
- **Debian** (bullseye, bookworm) - x86_64/amd64
- **Raspberry Pi OS** (bullseye, bookworm) - ARM64/ARM32

### 自動最適化
- **x86_64/amd64**: 4GB RAM, 最大20プレイヤー, 描画距離10
- **ARM64/ARM32** (Raspberry Pi 5, 8GB): 4GB RAM, 最大20プレイヤー,

## 特徴

### サポートするプラットフォーム
- ✅ Minecraft Java Edition (PC)
- ✅ Minecraft Bedrock Edition (モバイル、コンソール、Windows 10)
- ✅ オフラインモードでの認証
- ✅ クロスプラットフォームプレイヤー間でのチャット・インタラクション

### インストールされるプラグイン
- **Geyser-Spigot**: Bedrock Edition接続を可能にする
- **Floodgate**: Bedrock Editionプレイヤーの認証を処理
- **EssentialsX**: 基本的なサーバーコマンドとユーティリティ
- **ViaVersion**: 異なるMinecraftバージョン間の互換性
- **ViaBackwards**: 下位バージョンとの互換性

## ポート

| プロトコル | ポート | 用途 |
|-----------|--------|------|
| TCP | 25565 | Java Edition |
| UDP | 19132 | Bedrock Edition (Geyser) |
| TCP | 25575 | RCON |
| TCP | 9000 | Portainer |

## ディレクトリ構造

```
/opt/minecraft/
├── docker-compose.yml
├── .env
└── data/
    ├── server.properties
    ├── ops.json
    └── plugins/
        ├── Geyser-Spigot/
        │   └── config.yml
        └── floodgate/
            └── config.yml
```

## PlayIt.gg の実装について
### PlayIt.gg の設定手順

#### 🤖 完全自動設定（推奨）

PlayIt.ggは完全自動でセットアップされます：

1. **PlayIt.ggアカウント作成**
   - [https://playit.gg](https://playit.gg) でアカウント登録またはログイン

2. **ワンコマンドデプロイ**
   ```bash
   # PlayIt有効化してデプロイ（完全自動）
   ansible-playbook -i deploy/servers/inventory deploy/servers/playbooks/minecraft.yml \
     -e "playit_enabled=true"
   ```

3. **完全自動セットアップ**
   初回デプロイ時、Ansibleが自動実行：
   - ✅ PlayItコンテナを一時起動
   - ✅ Claim CodeとセットアップURLを自動抽出
   - ✅ vars/main.ymlに自動保存
   - ✅ ユーザーにセットアップ情報を表示

   出力例：
   ```
   ===============================================
   🔗 PlayIt.gg セットアップ - 自動設定完了
   ===============================================

   ✅ Claim Code: ABC123-DEF456
   🔗 セットアップURL: https://playit.gg/claim/ABC123-DEF456

   📋 次のステップ:
   1. 上記URLにアクセスしてPlayIt.ggアカウントにリンク
   2. リンク完了後、PlayItサービスが自動的に開始されます

   ⚠️ 重要:
   - Claim Codeは自動的にvars/main.ymlに保存されました
   - Playbookの再実行は不要です
   - アカウントリンク後、約30秒でトンネルが利用可能になります
   ===============================================
   ```

4. **アカウントリンクのみ**
   - 表示されたURLにアクセスしてアカウントにリンク
   - **設定ファイル編集や再実行は一切不要**
   - PlayItサービスが自動的に開始

#### 🔧 手動設定（バックアップ方法）

自動取得が失敗した場合：

```bash
# PlayItを手動起動
docker run --rm -it --net=host ghcr.io/playit-cloud/playit-agent:latest

# 表示されるClaim CodeをメモしてPlaybookで設定
```

#### トンネル設定

PlayIt.ggダッシュボードで以下のトンネルを作成：
- **Minecraft Java Edition**: TCP 25565
- **Minecraft Bedrock Edition**: UDP 19132

**✅ 利点**: 手動でのClaim Code抽出作業が不要になり、完全自動化されました。


### Docker vs システムインストール
このロールでは **Docker コンテナ** でPlayItを実装しています。理由：

#### ✅ Docker実装の利点
- **簡単な管理**: Docker Composeで一元管理
- **分離性**: ホストシステムに影響しない
- **ポータビリティ**: どの環境でも同じ動作
- **セキュリティ**: `network_mode: "container:minecraft-papermc-server"` でネットワーク共有

#### ❌ システムインストールの問題
- パッケージ管理の複雑性
- システム依存性
- アップデート時のリスク
- 権限管理の複雑性

### PlayIt設定
```yaml
# PlayItを有効にする場合
playit_secret_key: "your_secret_key_here"

# PlayItを無効にする場合（デフォルト）
playit_secret_key: ""
```

## 設定

### 基本設定
設定は [`vars/main.yml`](vars/main.yml) で管理されています：

```yaml
# プラットフォーム統一設定（Raspberry Pi 5で十分なリソース確保）
minecraft_memory: "4G"
minecraft_motd: "Your Server MOTD"
minecraft_max_players: 20
minecraft_difficulty: "normal"
minecraft_gamemode: "survival"
minecraft_pvp: true
minecraft_view_distance: 10
```

### Raspberry Pi 5でのメモリ配分 (8GB総容量)
```
システム予約:        ~1GB
Garage:              ~1GB
Minecraft:           4GB
その他/バッファ:      ~1.5GB
```

**注意**: Misskey本体は別サーバーで稼働するため、Raspberry Pi 5では十分なリソースでMinecraftサーバーを運用可能

### Geyser設定
Bedrockプレイヤーの接続設定：
- **ポート**: 19132 (UDP)
- **認証**: Floodgate経由
- **プレフィックス**: `.` (Bedrockプレイヤー名の前に付く)

### Floodgate設定
- **オフライン認証**: 有効
- **自動リンク**: 有効
- **スペース置換**: アンダースコアに置換

## デプロイ方法

### 1. 前提条件
必要なAnsibleコレクションをインストール：

```bash
# 必須コレクション
ansible-galaxy collection install community.docker

# 対象システムでDockerとDocker Composeが利用可能であることを確認
docker --version
docker-compose --version
```

### 2. 設定の確認
`group_vars/all.yml` または `host_vars/` で必要な変数を設定：

```yaml
minecraft_dir: '/opt/minecraft'
```

### 3. 基本デプロイ
```bash
ansible-playbook -i deploy/servers/inventory deploy/servers/playbooks/minecraft.yml
```

### 4. PlayIt.gg完全自動デプロイ
```bash
ansible-playbook -i deploy/servers/inventory deploy/servers/playbooks/minecraft.yml \
  -e "playit_enabled=true"
```

### 3. 環境変数の設定
必要に応じて `.env` ファイルを編集：
```bash
MEMORY=4G
RCON_PASSWORD=your_rcon_password
PLAYIT_SECRET_KEY=your_playit_key
```

## 接続方法

### Java Edition
- **サーバーアドレス**: `your-server-ip:25565`
- **バージョン**: 1.21.1 (ViaVersionにより他バージョンも対応)

### Bedrock Edition
- **サーバーアドレス**: `your-server-ip`
- **ポート**: `19132`
- **プレイヤー名**: 先頭に `.` が付きます (例: `.BedrockPlayer`)

## 管理

### サーバー管理
```bash
# サーバー起動
cd /opt/minecraft && docker-compose up -d

# サーバー停止
cd /opt/minecraft && docker-compose down

# ログ確認
cd /opt/minecraft && docker-compose logs -f minecraft

# RCON接続
docker exec -it minecraft-papermc-server rcon-cli
```

### Portainer
ブラウザで `http://your-server-ip:9000` にアクセスしてコンテナ管理

## トラブルシューティング

### 🔧 Ansible実行時の問題

1. **`community.docker` コレクションエラー**
   ```bash
   # 解決方法
   ansible-galaxy collection install community.docker
   ```

2. **Docker権限エラー**
   ```bash
   # ユーザーをdockerグループに追加
   sudo usermod -aG docker $USER
   # セッション再開後に有効
   ```

3. **PlayIt Claim Code取得失敗**
   - ネットワーク接続を確認
   - Dockerコンテナが正常に起動するか確認
   - 手動でPlayItコンテナを起動してログを確認

### 🎮 Minecraft接続の問題

1. **Bedrockプレイヤーが接続できない**
   - UDP ポート 19132 が開いているか確認
   - Geyser設定でポートが正しく設定されているか確認
   - ファイアウォール設定を確認

2. **認証エラー**
   - `online-mode=false` が設定されているか確認
   - Floodgate設定で認証タイプが `offline` になっているか確認

3. **メモリ不足**
   - `.env` ファイルの `MEMORY` 設定を調整
   - サーバーのRAM使用量を確認

4. **PlayIt.ggトンネル接続失敗**
   - PlayIt.ggアカウントでトンネル設定を確認
   - Secret Keyが正しく設定されているか確認
   - PlayItコンテナのログを確認: `docker logs playit-agent`

### ログの確認
```bash
# Minecraftサーバーログ
docker logs minecraft-papermc-server

# Geyserログ
docker exec minecraft-papermc-server tail -f /data/logs/latest.log | grep Geyser

# Floodgateログ
docker exec minecraft-papermc-server tail -f /data/logs/latest.log | grep Floodgate
```

## バックアップ

サーバーデータは以下のDockerボリュームに保存されます：
- `minecraft-data`: ワールドデータとサーバー設定
- `minecraft-plugins`: プラグインデータ
- `minecraft-config`: 各種設定ファイル

定期的なバックアップをお勧めします。

## アップデート

サーバーのアップデート：
```bash
cd /opt/minecraft
docker-compose pull
docker-compose up -d
```

プラグインは起動時に自動更新されます。

## 参考リンク

- [PaperMC](https://papermc.io/)
- [Geyser](https://geysermc.org/)
- [Floodgate](https://github.com/GeyserMC/Floodgate)
- [itzg/minecraft-server Docker Image](https://github.com/itzg/docker-minecraft-server)
