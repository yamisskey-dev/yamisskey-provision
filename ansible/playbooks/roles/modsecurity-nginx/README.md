# ModSecurity CRS NGINX Role

This role deploys ModSecurity with OWASP Core Rule Set (CRS) running on NGINX as a Docker container.

## Features

- **Web Application Firewall (WAF)**: Protects web applications from common attacks
- **OWASP Core Rule Set**: Pre-configured security rules for attack detection
- **Docker-based deployment**: Easy to deploy and manage
- **Customizable rules**: Support for custom rules before and after CRS
- **Health checks**: Built-in container health monitoring
- **SSL/TLS support**: HTTPS termination with configurable SSL settings

## Variables

### Required Variables
- `modsecurity_server_name`: Server name for the ModSecurity instance
- `modsecurity_backend`: Backend server URL to proxy requests to

### Optional Variables
- `modsecurity_blocking_paranoia`: Paranoia level for blocking (1-4, default: 2)
- `modsecurity_detection_paranoia`: Paranoia level for detection (1-4, default: 2)
- `modsecurity_anomaly_inbound`: Inbound anomaly score threshold (default: 5)
- `modsecurity_anomaly_outbound`: Outbound anomaly score threshold (default: 4)
- `modsecurity_nginx_port`: HTTP port (default: 8080)
- `modsecurity_nginx_ssl_port`: HTTPS port (default: 8443)

## Usage

1. Include the role in your playbook:
```yaml
- hosts: all
  roles:
    - modsecurity-nginx
```

2. Configure variables in group_vars or host_vars:
```yaml
modsecurity_server_name: "example.com"
modsecurity_backend: "http://127.0.0.1:3000"
modsecurity_blocking_paranoia: 2
```

3. Run the playbook:
```bash
ansible-playbook -i inventory modsecurity-nginx.yml
```

## Container Management

The ModSecurity NGINX container is managed through Docker Compose. Key commands:

- View logs: `docker-compose -f /etc/modsecurity-nginx/docker-compose.yml logs`
- Restart: `docker-compose -f /etc/modsecurity-nginx/docker-compose.yml restart`
- Stop: `docker-compose -f /etc/modsecurity-nginx/docker-compose.yml stop`

## Custom Rules

Custom rules can be added through variables:

```yaml
modsecurity_custom_rules_before:
  - 'SecRule REQUEST_URI "@rx ^/admin" "id:1001,phase:1,deny,status:403"'

modsecurity_custom_rules_after:
  - 'SecRule RESPONSE_STATUS "@rx ^5" "id:2001,phase:4,log"'
```

## Security Considerations

- The container runs with least privilege
- Custom SSL certificates should be mounted for production use
- Log files are rotated and managed by the host system
- Regular updates of the ModSecurity CRS image are recommended
