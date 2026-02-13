# yamisskey.servers role: minio - tasks

`minio` ロールのタスク定義を格納します。`minio.yml` からロールが呼び出され、以下を実施します。

主な処理:
- ディレクトリ作成: `/opt/minio`, `/opt/minio/minio-data`
- シークレット読込: host_vars `<host>/secrets.yml` の `minio.*` を参照（SOPS）
- テンプレート展開: `minio_docker-compose.yml.j2` → `/opt/minio/docker-compose.yml`
- Docker 起動: Compose v2 で MinIO を起動、`external_network` 作成
- ヘルスチェック: `/minio/health/live` を確認
- MinIO Client `mc` 導入・エイリアス設定
- バケット/IAM 作成: Misskey 用バケットとユーザ、ポリシー作成、SSE-S3 有効化

代表変数（例: `group_vars`/`host_vars` で上書き）:
```yaml
minio_alias: yaminio
minio_bucket_name_for_misskey: files
```

SOPS シークレット例（`deploy/servers/host_vars/<host>/secrets.yml`）:
```yaml
minio:
  root_user: "minio-admin"
  root_password: "super-secure-root-password"
  misskey_s3_access_key: "misskey-access"
  misskey_s3_secret_key: "misskey-secret"
  kms_master_key: "minio-master-key-CHANGE-ME"
```

実行例:
- 確認: `make check PLAYBOOK=minio`
- 実行: `make run PLAYBOOK=minio`
