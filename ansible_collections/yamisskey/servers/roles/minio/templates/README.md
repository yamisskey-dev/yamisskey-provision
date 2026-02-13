# yamisskey.servers role: minio - templates

`minio` ロールの Jinja2 テンプレートを格納します。`tasks/main.yml` から以下が展開されます。

- `minio_docker-compose.yml.j2` → `/opt/minio/docker-compose.yml`
- `minio_iam_policy.json.j2` → 一時ファイル `/tmp/minio_iam_policy.json`（作成後に削除）
- `minio_cors_policy.json.j2` → 一時ファイル `/tmp/minio_bucket_policy.json`（作成後に削除）

関連変数（抜粋）:
- `minio_alias`（例: `yaminio`）
- `minio_api_server_name`
- `minio_bucket_name_for_misskey`（例: `files`）

実行例:
- 確認: `make check PLAYBOOK=minio`
- 実行: `make run PLAYBOOK=minio`
