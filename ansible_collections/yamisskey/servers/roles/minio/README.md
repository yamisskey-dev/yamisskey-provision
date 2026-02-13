# yamisskey.servers role: minio

Secure MinIO object storage deployment with CLI-only management and ActivityPub federation support.

## Overview

This role deploys a production-ready MinIO instance with enhanced security features specifically designed for ActivityPub federation platforms like Misskey. The Web UI is disabled for security, and access is controlled through multiple layers of protection.
🔐 **Secrets**: Define `minio.*` values in the target host's `host_vars/<host>/secrets.yml` (SOPS) – no local `secrets.yml` is created by the role.

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

### 📦 Application Support
- **Misskey Integration**: File storage for social media platform
- **Automatic Bucket Creation**: Creates `files` bucket

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
- **Bucket Scope**: Access limited to `files` bucket only

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

# Verify encryption (should show KMS encryption enabled)
mc encrypt info yaminio/files

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
2. **Monitor Access Logs**: Review Nginx logs for suspicious activity
4. **Security Updates**: Keep MinIO and dependencies updated
5. **Access Auditing**: Review IAM policies and bucket permissions

## Migration Notes

This configuration specifically addresses the MinIO Web UI removal issue while maintaining:
- ✅ **URL Preservation**: Existing `https://drive.yami.ski/files` URLs continue working
- ✅ **Federation Compatibility**: All ActivityPub platforms can access content
- ✅ **Security Enhancement**: Improved security posture with CLI-only management
- ✅ **Application Support**: Misskey integration

The deployment is production-ready and provides enterprise-grade security for ActivityPub federation environments.
