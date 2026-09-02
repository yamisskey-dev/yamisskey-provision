# yamisskey.servers role: hermes

Hermes Agent（NousResearch）をログインユーザーの `~/.hermes` に導入し、user systemd + linger で常時起動させるロールです。

- 呼び出し例: `task run PLAYBOOK=hermes`
- 管理対象: 上流インストーラの実行（初回のみ。`hermes_commit` でピン留め）、`.env`、`config.yaml`、user systemd ユニット（gateway / dashboard）、linger
- 管理対象外（hermes 側の所有物）: `SOUL.md`、`state.db`、`sessions/`、`memories/`、`skills/`
- シークレット: `host_vars/<host>/secrets.sops.yml` の `hermes.*`。キー名を大文字化して `.env` に書き出す（`hermes.telegram_bot_token` → `TELEGRAM_BOT_TOKEN`）
- 非シークレットの `.env` 設定（timeout / debug フラグ等）は `defaults/main.yml` の `hermes_env_settings`。同名キーは SOPS 側が優先
- `config.yaml` は `templates/config.yaml.j2` が source of truth。hermes 自身も書き戻す（setup / dashboard / `doctor --fix`）ので、
  ホスト側で変わったフィールドはテンプレートへ反映する。可変にしている項目は `defaults/main.yml` の `hermes_model*` / `hermes_max_turns` / `hermes_disabled_toolsets` など
- dashboard は loopback にのみ bind し、`tailscale serve` で `https://<host>.<tailnet>.ts.net` として tailnet 内に公開する（`hermes_dashboard_public_url`）。Hermes Desktop の接続先はその URL
- バージョン更新: `hermes_commit` を書き換えて再実行、または melchior 上で `hermes update` 後に sha を追従させる。
  hermes の config 移行（`_config_version`）が進んだらテンプレートも更新する
