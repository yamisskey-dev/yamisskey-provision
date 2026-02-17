# yamisskey.servers role: export - tasks

`export` ロールのタスク定義を格納します。ソースサーバ上の Docker Compose プロジェクトを停止し、ディレクトリごとに `.tar.gz` を作成、宛先へコピーします。

対象ディレクトリ:
- `/var/www/<service>`（`docker_services_www`）
- `/opt/<service>`（`docker_services_opt`）
- `/home/{{ ansible_user }}/<service>`（`docker_services_home`）

代表変数例（`vars/main.yml`）:
```yaml
backup_dir: /var/backups
docker_services_www: [misskey, synapse]
docker_services_opt: [misskey-backup, garage]
docker_services_home: [ai, ctfd]
```

インベントリ構成:
- `source` グループのホストでバックアップと送信を実行
- `destination` グループの先頭ホストに `delegate_to` で転送
