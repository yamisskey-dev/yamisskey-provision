# MinIO Role

Secure MinIO object storage deployment with CLI-only management and ActivityPub federation support.

## Overview

This role deploys a production-ready MinIO instance with enhanced security features specifically designed for ActivityPub federation platforms like Misskey. The Web UI is disabled for security, and access is controlled through multiple layers of protection.

## Features

### 🛡️ Security
- **Web UI Disabled**: CLI management only for enhanced security
- **Multi-layer Access Control**: Nginx + IAM + Bucket policies
- **Direct Browser Access Prevention**: Blocks unauthorized direct access
- **Rate Limiting**: DDoS protection with 60 req/min limit
- **Server-Side Encryption**: Data at rest protection with KMS (SSE-S3 + KMS)
- **Tailscale Network Integration**: Secure internal communication

### 🌐 Federation Support
- **ActivityPub Compatible**: Supports all major federation platforms
  - Misskey, Mastodon, Pleroma, Firefish, Calckey, Foundkey
  - Akkoma, Sharkey, Iceshrimp, GoToSocial, Pixelfed
- **URL Preservation**: Maintains existing `https://drive.yami.ski/files` URLs
- **Cloudflare Integration**: CDN and DDoS protection

### 📦 Multi-Application Support
- **Misskey Integration**: File storage for social media platform
- **Outline Integration**: Asset storage for wiki/documentation
- **Multiple Buckets**: Automatic creation of `files` and `assets` buckets

## Architecture

```
Internet → Cloudflare → Nginx (Port 8080) → MinIO (Port 9000)
                ↓
        Rate Limiting + Access Control
                ↓
        ActivityPub Federation ✅
        Direct Browser Access ❌
```

### Network Flow
1. **Internal Communication**: Misskey (balthasar) → MinIO (raspberrypi) via Tailscale
2. **External Access**: Federation platforms → Cloudflare → Nginx → MinIO
3. **Upload Path**: Applications → Tailscale → MinIO directly
4. **Download Path**: Federation → Cloudflare → Nginx → MinIO

## Prerequisites

### Required Variables in `group_vars/all.yml`
```yaml
# Domain configuration
domain: yami.ski
minio_api_server_name: drive.{{ domain }}

# Bucket names
minio_bucket_name_for_misskey: "files"
minio_bucket_name_for_outline: "assets"

# Secrets file location
minio_secrets_file: '/opt/minio/secrets.yml'

# MinIO alias for CLI operations
minio_alias: yaminio
```

### Secrets File (`/opt/minio/secrets.yml`) - **完全自動生成対応**

#### 🎯 **Zero Configuration Required**
このロールは**完全自動化**されており、`secrets.yml`ファイルが存在しない場合は全ての必要な認証情報を自動生成します。

```yaml
# この構造は自動生成されます - 手動作成不要
minio:
  root_user: "auto-generated-32-chars"           # 自動生成: 32文字
  root_password: "auto-generated-64-chars"       # 自動生成: 64文字
  misskey_s3_access_key: "hostname-timestamp"    # 自動生成: ホスト名-タイムスタンプ
  misskey_s3_secret_key: "auto-generated-32-chars" # 自動生成: 32文字
  kms_master_key: "minio-master-key:base64-key"  # 自動生成: KMS暗号化キー
```

#### 📋 **動作パターン**
1. **初回デプロイ**: `secrets.yml`が存在しない → 全認証情報を自動生成して保存
2. **再デプロイ**: `secrets.yml`が存在する → 既存の設定を使用（変更なし）
3. **部分設定**: 一部の設定のみ存在 → 不足分のみ自動生成して追加

#### ✅ **設定例（オプション）**
必要に応じて手動で設定をカスタマイズできます：
```yaml
minio:
  root_user: "custom-admin"                      # カスタム設定
  root_password: "your-secure-root-password"     # カスタム設定
  # 以下は自動生成されます（設定がない場合）
  misskey_s3_access_key: "auto-generated"
  misskey_s3_secret_key: "auto-generated"
  kms_master_key: "auto-generated"
```

**重要**: 自動生成された認証情報は`/opt/minio/secrets.yml`に安全に保存され、再デプロイ時に再利用されます。

### System Requirements
- Docker and Docker Compose
- UFW firewall
- Tailscale network setup
- Nginx reverse proxy

## Security Configuration

### 1. Web UI Security
- **MINIO_BROWSER=off**: Completely disables web interface
- **Port 9001 Not Exposed**: Console port only accessible internally
- **CLI Management Only**: All administration via MinIO Client (`mc`)

### 2. Access Control Layers

#### Layer 1: Nginx (External Access)
- **Rate Limiting**: 60 requests/minute with burst=20
- **User-Agent Validation**: Blocks direct browser access
- **Referer Checks**: Allows federation platforms only
- **Method Restrictions**: Controls upload operations

#### Layer 2: IAM (User Level)
- **Dedicated User**: Auto-generated user with minimal permissions
- **Restricted Policy**: Only `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`
- **Bucket Scope**: Access limited to `files` and `assets` buckets only

#### Layer 3: Bucket Policies (Resource Level)
- **Conditional Access**: ActivityPub platforms with User-Agent verification
- **Read-Only Federation**: External platforms can only read objects
- **Upload Restrictions**: Only authenticated applications can upload

### 3. Network Security
- **Tailscale Access**: UFW allows Tailscale network (100.64.0.0/10)
- **Firewall Protection**: MinIO port 9000 restricted to Tailscale
- **Cloudflare Integration**: External access only through CDN

## Deployment

### 1. Run the Role - **完全自動デプロイ**
```bash
ansible-playbook -i inventory site.yml --tags minio
```

### 2. Verify Deployment
The role will display a configuration summary with:
- ✅ Security features enabled
- ✅ Bucket creation status
- ✅ IAM user configuration
- 🔑 **Auto-generated credentials** (saved to `/opt/minio/secrets.yml`)

### 3. Get Auto-Generated Credentials
```bash
# View generated credentials
cat /opt/minio/secrets.yml

# Or get specific values
grep "misskey_s3_access_key" /opt/minio/secrets.yml
grep "misskey_s3_secret_key" /opt/minio/secrets.yml
```

### 4. Configure Applications

#### Misskey Configuration (balthasar server)
Add to Misskey's `.env` file:
```env
# S3/MinIO Configuration via Tailscale
S3_BUCKET=files
S3_PREFIX=""
S3_ENDPOINT=http://[TAILSCALE_RASPBERRYPI_IP]:9000
S3_ACCESS_KEY=raspberry-1733364727    # 例：自動生成された値
S3_SECRET_KEY=k3mB7xN9qZ8wR4yT2vS6h...  # 例：自動生成された値
S3_REGION=ap-northeast-3
S3_USE_SSL=false
S3_FORCE_PATH_STYLE=true
# Public URL for federation (via Cloudflare)
S3_BASE_URL=https://drive.yami.ski/files
```

#### Outline Configuration
Add to Outline's `.env` file:
```env
# S3/MinIO Configuration for Outline
AWS_S3_UPLOAD_BUCKET_NAME=assets
AWS_S3_UPLOAD_BUCKET_URL=https://drive.yami.ski/assets
AWS_S3_UPLOAD_MAX_SIZE=104857600
AWS_REGION=ap-northeast-3
AWS_ACCESS_KEY_ID=raspberry-1733364727    # Misskeyと同じ自動生成値
AWS_SECRET_ACCESS_KEY=k3mB7xN9qZ8wR4yT2vS6h...  # Misskeyと同じ自動生成値
```

**重要**:
- 全ての認証情報は自動生成され、`/opt/minio/secrets.yml`に安全に保存されます
- 同じ認証情報がMisskeyとOutlineの両方で使用されます
- 再デプロイ時は既存の認証情報が保持されます（変更されません）

## Management

### MinIO Client Commands
```bash
# Set alias (done automatically by role)
mc alias set yaminio http://[CONTAINER_IP]:9000 admin [password]

# List buckets
mc ls yaminio

# List objects in files bucket
mc ls yaminio/files

# Create new bucket
mc mb yaminio/new-bucket

# Set bucket policy
mc anonymous set download yaminio/bucket-name

# User management
mc admin user list yaminio
mc admin policy list yaminio
```

### Monitoring
```bash
# Check container status
docker ps | grep minio

# View logs
docker logs minio

# Check disk usage
mc admin info yaminio
```

## Troubleshooting

### Common Issues

#### 1. Federation Images Not Loading
**Problem**: Images don't display in other ActivityPub instances  
**Solution**: Check Nginx access logs and verify User-Agent patterns
```bash
# Check Nginx logs
docker logs modsecurity-nginx | grep minio

# Test federation access
curl -H "User-Agent: Misskey/13.0.0" https://drive.yami.ski/files/test.jpg
```

#### 2. Upload Failures
**Problem**: Applications can't upload files
**Solution**: Verify Tailscale connectivity and IAM permissions
```bash
# Test Tailscale connection
ping [TAILSCALE_RASPBERRYPI_IP]

# Get auto-generated access key from secrets
ACCESS_KEY=$(grep "misskey_s3_access_key" /opt/minio/secrets.yml | cut -d'"' -f4)

# Check IAM user with auto-generated credentials
mc admin user info yaminio $ACCESS_KEY
```

#### 3. Direct Access Not Blocked
**Problem**: Browser can access MinIO directly  
**Solution**: Verify Nginx configuration and rate limiting
```bash
# Test direct browser access (should be blocked)
curl -H "User-Agent: Mozilla/5.0" https://drive.yami.ski/files/
```

### Health Checks
```bash
# MinIO health endpoint
curl http://localhost:9000/minio/health/live

# Check bucket policies
mc stat yaminio/files
mc stat yaminio/assets

# Verify encryption (should show KMS encryption enabled)
mc encrypt info yaminio/files
mc encrypt info yaminio/assets

# Check KMS configuration
mc admin config get yaminio kms
```

## File Structure

```
roles/minio/
├── README.md                    # This documentation
└── tasks/main.yml              # Main deployment tasks

playbooks/templates/
├── minio_docker-compose.yml.j2       # Docker Compose template
├── minio_iam_policy.json.j2          # IAM user policy
└── minio_cors_policy.json.j2         # Bucket access policy

playbooks/roles/modsecurity-nginx/templates/conf.d/
└── minio.conf.j2                     # Nginx reverse proxy config
```

## Security Considerations

### ✅ Implemented Protections
- Web UI completely disabled
- Multi-layer access control (Nginx + IAM + Bucket)
- Rate limiting and DDoS protection
- Server-side encryption for privacy
- Network isolation via Tailscale
- User-Agent and Referer validation

### ⚠️ Important Notes
- **CLI Only**: All management must be done via MinIO Client
- **No Direct Access**: Browser access is intentionally blocked
- **Federation Dependent**: External access only through ActivityPub platforms
- **Tailscale Required**: Internal application access requires Tailscale network

### 🔒 Best Practices
1. **Secret Management**:
   - 自動生成された認証情報は`/opt/minio/secrets.yml`に安全に保存されます
   - ファイルの権限は自動的に`600`（所有者のみ読み書き可能）に設定されます
   - 定期的なローテーション時は`secrets.yml`を削除してから再デプロイすると新しい認証情報が生成されます
2. **Monitor Access Logs**: Review Nginx logs for suspicious activity
3. **Backup Strategy**:
   - MinIOデータのバックアップ
   - `/opt/minio/secrets.yml`ファイルのバックアップ（認証情報復元のため）
4. **Security Updates**: Keep MinIO and dependencies updated
5. **Access Auditing**: Review IAM policies and bucket permissions

### 🔄 **認証情報のローテーション手順**
```bash
# 1. 現在の認証情報をバックアップ
cp /opt/minio/secrets.yml /opt/minio/secrets.yml.backup

# 2. secrets.ymlを削除（新しい認証情報を強制生成）
rm /opt/minio/secrets.yml

# 3. MinIOロールを再実行（新しい認証情報が自動生成される）
ansible-playbook -i inventory site.yml --tags minio

# 4. 新しい認証情報でアプリケーション設定を更新
cat /opt/minio/secrets.yml
```

## Migration Notes

This configuration specifically addresses the MinIO Web UI removal issue while maintaining:
- ✅ **URL Preservation**: Existing `https://drive.yami.ski/files` URLs continue working
- ✅ **Federation Compatibility**: All ActivityPub platforms can access content
- ✅ **Security Enhancement**: Improved security posture with CLI-only management
- ✅ **Application Support**: Both Misskey and Outline integration

The deployment is production-ready and provides enterprise-grade security for ActivityPub federation environments.