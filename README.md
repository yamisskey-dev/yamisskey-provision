# Provisioning servers with Make and Ansible

This guide will walk you through the process of setting up Misskey etc using the provided Make and Ansible.

## Steps

### login

Prepare to log in to VPS as a general user with SSH private key:

```consol
adduser your_username
usermod -aG sudo your_username
vi /etc/ssh/sshd_config
```

`/etc/ssh/sshd_config`

```config
RSAAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin  no
```

```consol
systemctl restart sshd
su your_username
mkdir ~/.ssh
vi ~/.ssh/id_ed25519_vps.pub
touch ~/.ssh/authrized_keys
cat ~/.ssh/id_ed25519_vps.pub >>  ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

### clone

Clone the yamisskey-provision repository from GitLab to your local machine:

`~/.ssh/config`

```config
Host hostname
    User your_username
    port 22
    Hostname 00.000.000.000
    IdentityFile ~/.ssh/id_ed25519_vps
    TCPKeepAlive yes
    IdentitiesOnly yes
```

```consol
ssh vps.com
git clone https://github.com/yamisskey/yamisskey-provision.git
cd yamisskey-provision
```

### install

Use the Makefile to install the necessary packages and clone the misskey repository:

```consol
make install
make clone
```

### edit

Navigate to the `misskey` directory inside the misskey directory and copy the configuration file templates:

```consol
cd ~/misskey
cp docker-compose_example.yml docker-compose.yml
cd .config
cp docker_example.yml default.yml
cp docker_example.env docker.env
```
Edit the `docker-compose.yml` and `default.yml` and `docker.env` files, providing the appropriate configuration values. Refer to the comments within the files for guidance.

- Change 3000 port to 3001 which conflicts with grafana in `docker-compose.yml` and `default.yml`
- Change domain example.tld to yami.ski in `default.yml`
- Change host of db from localhost to db and host of redis from localhost to redis in `default.yml`
- Change name and user and pass in `default.yml` and `docker.env`

[Configure Nginx](https://misskey-hub.net/ja/docs/for-admin/install/resources/nginx/) to reverse proxy Misskey. Ensure the Misskey Nginx configuration `misskey.conf` is properly set up to handle HTTP to HTTPS redirection, WebSocket support, and SSL configuration.

- Change 3000 port to 3001 which conflicts with grafana
- Change domain example.tld to yami.ski

### configure
Prepare the Cloudflare API credentials file. Create a directory for Cloudflare configuration if it does not exist:

- Access https://dash.cloudflare.com/profile/api-tokens
- Select View for Global API Key
- Enter password to remove hCaptcha and select View

```consol
sudo mkdir /etc/cloudflare
sudo vi /etc/cloudflare/cloudflare.ini
```

Include the following content, replacing placeholders with your actual data:

```config
dns_cloudflare_email = your-email@example.com
dns_cloudflare_api_key = your-cloudflare-global-api-key
```

```consol
sudo chmod 600 /etc/cloudflare/cloudflare.ini
```

### init

Need to manually log in to tailscale, cloudflared and warp

#### tailscale
```consol
tailscale login
sudo tailscale up --advertise-tags=tag:ssh-access --ssh --accept-dns=false --reset --accept-risk=lose-ssh
```

#### cloudflared
```consol
cloudflared tunnel login
```

##### locally-managed tunnel

```consol
cloudflared tunnel create yamisskey
cloudflared tunnel list
sudo mkdir -p /etc/cloudflared
sudo vim /etc/cloudflared/config.yml
```

```yml
tunnel: <Tunnel-UUID>
credentials-file: /home/taka/.cloudflared/<Tunnel-UUID>.json
origincert: /home/taka/.cloudflared/cert.pem
warp-routing:
  enabled: true
protocol: http2
dns:
  upstreams:
    - 127.0.0.1:5353
retries: 5
timeout: 15s
compression: true
noTLSVerify: false
originRequest:
  disableChunkedEncoding: true
  connectTimeout: 10s
  keepAliveTimeout: 30s

ingress:
  - hostname: yami.ski
    service: http://localhost:8080
  - hostname: bypass.yami.ski
    service: http://localhost:8080
  - hostname: search.yami.ski
    service: http://localhost:8082
  - hostname: matrix.yami.ski
    service: http://localhost:8008
  - hostname: chat.yami.ski
    service: http://localhost:8081
  - hostname: ctf.yami.ski
    service: http://localhost:8000
  - hostname: drive.yami.ski
    service: http://localhost:9000
  - hostname: minio.yami.ski
    service: http://localhost:9001
  - hostname: call.yami.ski
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true
  - hostname: grafana.yami.ski
    service: http://localhost:3000
  - hostname: task.yami.ski
    service: http://localhost:3456
  - hostname: pad.yami.ski
    service: http://localhost:3333
  - hostname: wiki.yami.ski
    service: http://localhost:3004
  - hostname: uptime.yami.ski
    service: http://localhost:3009
  - hostname: auth.yami.ski
    service: http://localhost:8993
    originRequest:
      noTLSVerify: true
      http2Origin: true
      proxyType: "h2c"
  - hostname: captcha.yami.ski
    service: http://localhost:7493
  - hostname: neo-quesdon.yami.ski
    service: http://localhost:3025
  - service: http_status:404
```

```consol
sudo cloudflared tunnel --config /home/taka/.cloudflared/config.yml run yamisskey
```

```consol
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
sudo systemctl restart cloudflared
```

##### cloudflare zero trust(optional)
create cloudflare tunnel named yamisskey by Zero Trust in https://one.dash.cloudflare.com/
```consol
sudo cloudflared service install your_connector_token_value
```

#### warp-cli

##### warp+

subscribe warp licence key on mobile device
```consol
warp-cli registration new
warp-cli registration license <your-warp-licence-key-subscribed-on-mobile-device>
warp-cli registration show
warp-cli connect
curl https://www.cloudflare.com/cdn-cgi/trace/
```
verify that warp=on.

##### cloudflare zero trust(optional)
create cloudflare tunnel named yamisskey-warp by Zero Trust in https://one.dash.cloudflare.com/

copy mdm.xml to /var/lib/cloudflare-warp/mdm.xml
```xml
<dict>
  <key>organization</key>
  <string>yamisskey</string>
  <key>auth_client_id</key>
  <string>your_client_id_access_value</string>
  <key>auth_client_secret</key>
  <string>your_client_secret_value</string>
  <key>warp_connector_token</key>
  <string>your_connector_token_value</string>
</dict>
```

```consol
sudo systemctl restart warp-svc.service
```

### ai

You need to manually prepare the configuration file `config.json` in ai repository to run. please see [this document](https://github.com/yamisskey/yui?tab=readme-ov-file#docker%E3%81%A7%E5%8B%95%E3%81%8B%E3%81%99).

### provision

Return to the yamisskey-provision directory and use the Makefile to provision the server:

```consol
cd ~/yamisskey-provision
make provision
```

During the provisioning process, the Ansible playbook (playbook.yml) will pause and prompt you to review the configuration files you edited in step 4. Ensure that the configurations are correct, then press ENTER to continue the provisioning process. Once the provisioning is complete, verify that Misskey is running correctly.

 ### backup
 
Ensure that you have the necessary environment variables set up to backup. Create a .env file in the misskey-backup directory if it does not exist, and provide the required values:

```config
POSTGRES_HOST=your_postgres_host_in_misskey_config
POSTGRES_USER=your_postgres_user_in_misskey_config
POSTGRES_DB=your_postgres_namein_misskey_config
POSTGRES_PASSWORD=your_postgres_passwordin_misskey_config
R2_PREFIX=your_cloudflare_r2_bucket_prefix
DISCORD_WEBHOOK_URL=your_discord_server_channel_webhook_url
NOTIFICATION=true
```

```consol
make backup
```