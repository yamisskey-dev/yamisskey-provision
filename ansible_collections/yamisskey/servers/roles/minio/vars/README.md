# yamisskey.servers role: minio - vars

`minio` ロールの変数定義を格納します。`vars/main.yml` の主な値:

```yaml
minio_alias: yaminio
minio_api_server_name: "drive.{{ domain }}"
minio_bucket_name_for_misskey: "files"
```

上書き例（`group_vars/all/main.yml` など）:
```yaml
minio_alias: default
```

機微情報は SOPS (group_vars/all/ or host_vars/<host>/secrets.yml) で管理してください。
