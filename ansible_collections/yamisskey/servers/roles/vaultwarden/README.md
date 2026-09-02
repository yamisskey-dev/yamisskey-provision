# yamisskey.servers role: vaultwarden

Vaultwarden（Bitwarden 互換パスワードマネージャー）を Docker Compose で導入・設定するロールです。

- 呼び出し例: `task run PLAYBOOK=vaultwarden`
- 前提: Docker と `docker compose` プラグインが導入済みであること（このロールでは入れない）
- 公開経路: `127.0.0.1:{{ vaultwarden_port }}` にのみ bind し、外部公開は cloudflared ロールの ingress に任せる
- シークレット: `host_vars/<host>/secrets.sops.yml` の `vaultwarden.admin_token`
- イメージタグは `vaultwarden_image` でピン留め。更新は defaults を書き換えて再実行する
