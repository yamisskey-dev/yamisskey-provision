.PHONY: all install inventory clone migrate test provision backup update help

DESTINATION_SSH_USER=$(shell whoami)
DESTINATION_HOSTNAME=$(shell hostname)
DESTINATION_IP=$(shell tailscale status | grep $(DESTINATION_HOSTNAME) | awk '{print $$1}')
DESTINATION_SSH_PORT=22
OS=$(shell lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(shell lsb_release -cs)
ARCH=$(shell dpkg --print-architecture)
USER=$(shell whoami)
TIMESTAMP=$(shell date +%Y%m%dT%H%M%S`date +%N | cut -c 1-6`)
GITHUB_ORG=yamisskey-dev
GITHUB_ORG_URL=https://github.com/$(GITHUB_ORG)
MISSKEY_REPO=$(GITHUB_ORG_URL)/yamisskey.git
MISSKEY_DIR=/var/www/misskey
MISSKEY_BRANCH=master
CONFIG_FILES=$(MISSKEY_DIR)/.config/default.yml $(MISSKEY_DIR)/.config/docker.env
AI_DIR=$(HOME)/ai
BACKUP_SCRIPT_DIR=/opt/misskey-backup
ANONOTE_DIR=$(HOME)/misskey-anonote
ASSETS_DIR=$(HOME)/misskey-assets
CTFD_DIR=$(HOME)/ctfd
ENV_FILE=.env

# Load environment variables if .env file exists
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export $(shell sed 's/=.*//' $(ENV_FILE))
endif

all: install inventory clone provision backup update

install:
	@echo "Installing Ansible..."
	@sudo apt-get update && sudo apt-get install -y ansible || (echo "Install failed" && exit 1)
	@echo "Installing Ansible collections..."
	@ansible-galaxy collection install -r ansible/requirements.yml
	@echo "Installing necessary packages..."
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/common.yml --ask-become-pass
	@echo "Installing Tailscale..."
	@curl -fsSL https://tailscale.com/install.sh | sh
	@echo "Installing Cloudflare Warp..."
	@curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
	@echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(CODENAME) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
	@sudo apt-get update && sudo apt-get install -y cloudflare-warp
	@echo "Installing Cloudflared..."
	@wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$(ARCH).deb
	@sudo dpkg -i cloudflared-linux-$(ARCH).deb
	@rm -f cloudflared-linux-$(ARCH).deb
	@echo "Installing Docker..."
	@sudo install -m 0755 -d /etc/apt/keyrings
	@sudo curl -fsSL https://download.docker.com/linux/$(OS)/gpg -o /etc/apt/keyrings/docker.asc
	@sudo chmod a+r /etc/apt/keyrings/docker.asc
	@echo "deb [arch=$(ARCH) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(OS) $(CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	@sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || (echo "Docker installation failed" && exit 1)
	@curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
	@echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list
	@sudo apt update
	@@sudo apt install playit

inventory:
	@echo "Creating inventory file..."
	@if [ -n "$(SOURCE)" ] && [ -n "$(TARGET)" ]; then \
		echo "Creating migration inventory for $(SOURCE) → $(TARGET)..."; \
		SOURCE_IP=$$(tailscale status 2>/dev/null | grep "$(SOURCE)" | awk '{print $$1}' | head -1 || echo "$(SOURCE)"); \
		TARGET_IP=$$(tailscale status 2>/dev/null | grep "$(TARGET)" | awk '{print $$1}' | head -1 || echo "$(TARGET)"); \
		CURRENT_HOST=$$(hostname); \
		echo "[source_hosts]" > ansible/inventory; \
		if [ "$$CURRENT_HOST" = "$(SOURCE)" ]; then \
			echo "$(SOURCE) ansible_connection=local" >> ansible/inventory; \
		else \
			echo "$(SOURCE) ansible_host=$$SOURCE_IP ansible_user=$(USER) ansible_port=22" >> ansible/inventory; \
		fi; \
		echo "" >> ansible/inventory; \
		echo "[target_hosts]" >> ansible/inventory; \
		if [ "$$CURRENT_HOST" = "$(TARGET)" ]; then \
			echo "$(TARGET) ansible_connection=local" >> ansible/inventory; \
		else \
			echo "$(TARGET) ansible_host=$$TARGET_IP ansible_user=$(USER) ansible_port=22" >> ansible/inventory; \
		fi; \
		echo "" >> ansible/inventory; \
		echo "[all:vars]" >> ansible/inventory; \
		echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10'" >> ansible/inventory; \
		echo "ansible_python_interpreter=/usr/bin/python3" >> ansible/inventory; \
		echo "ansible_ssh_pipelining=true" >> ansible/inventory; \
		echo "ansible_become=true" >> ansible/inventory; \
		echo "ansible_become_method=sudo" >> ansible/inventory; \
		echo "ansible_become_user=root" >> ansible/inventory; \
		echo "Migration inventory created at ansible/inventory"; \
		echo "Source: $(SOURCE) ($$SOURCE_IP)"; \
		echo "Target: $(TARGET) ($$TARGET_IP)"; \
	else \
		echo "Creating default inventory..."; \
		echo "[source]" > ansible/inventory; \
		echo "$(shell hostname) ansible_connection=local" >> ansible/inventory; \
		echo "" >> ansible/inventory; \
		echo "[destination]" >> ansible/inventory; \
		echo "$(DESTINATION_HOSTNAME) ansible_host=$(DESTINATION_IP) ansible_user=$(DESTINATION_SSH_USER) ansible_port=$(DESTINATION_SSH_PORT) ansible_become=true" >> ansible/inventory; \
		echo "Default inventory file created at ansible/inventory"; \
	fi

clone:
	@echo "Cloning repositories if not already present..."
	@sudo mkdir -p $(MISSKEY_DIR)
	@sudo chown $(USER):$(USER) $(MISSKEY_DIR)
	@if [ ! -d "$(MISSKEY_DIR)/.git" ]; then \
		git clone $(MISSKEY_REPO) $(MISSKEY_DIR); \
		cd $(MISSKEY_DIR) && git checkout $(MISSKEY_BRANCH); \
	fi
	@sudo mkdir -p $(ASSETS_DIR)
	@sudo chown $(USER):$(USER) $(ASSETS_DIR)
	@if [ ! -d "$(ASSETS_DIR)/.git" ]; then \
		git clone $(GITHUB_ORG_URL)/yamisskey-assets.git $(ASSETS_DIR); \
	fi
	@mkdir -p $(AI_DIR)
	@if [ ! -d "$(AI_DIR)/.git" ]; then \
		git clone $(GITHUB_ORG_URL)/yui.git $(AI_DIR); \
	fi
	@mkdir -p $(BACKUP_SCRIPT_DIR)
	@if [ ! -d "$(BACKUP_SCRIPT_DIR)/.git" ]; then \
		git clone $(GITHUB_ORG_URL)/yamisskey-backup.git $(BACKUP_SCRIPT_DIR); \
	fi
	@mkdir -p $(ANONOTE_DIR)
	@if [ ! -d "$(ANONOTE_DIR)/.git" ]; then \
		git clone $(GITHUB_ORG_URL)/yamisskey-anonote.git $(ANONOTE_DIR); \
	fi
	@mkdir -p $(CTFD_DIR)
	@if [ ! -d "$(CTFD_DIR)/.git" ]; then \
		git clone $(GITHUB_ORG_URL)/ctf.yami.ski.git $(CTFD_DIR); \
	fi

migrate:
	@echo "Migrating MinIO data with encryption..."
	@echo "Usage examples:"
	@echo "  make migrate                           # Default: source→destination"
	@echo "  make migrate SOURCE=balthasar TARGET=raspberrypi  # Custom hosts"
	@if [ -n "$(SOURCE)" ] && [ -n "$(TARGET)" ]; then \
		echo "Creating migration inventory and executing..."; \
		$(MAKE) inventory SOURCE=$(SOURCE) TARGET=$(TARGET); \
		ansible-playbook -i ansible/inventory \
			-e "migrate_source=$(SOURCE) migrate_target=$(TARGET)" \
			--limit $(TARGET) ansible/playbooks/migrate.yml; \
	else \
		echo "Using default source→destination migration..."; \
		$(MAKE) inventory; \
		ansible-playbook -i ansible/inventory --limit destination ansible/playbooks/migrate.yml; \
	fi

test:
	@echo "=== MinIO Migration System Test ==="
	@echo ""
	@echo "Test 1: Basic inventory generation..."
	@$(MAKE) inventory > /dev/null 2>&1
	@if [ -f ansible/inventory ]; then \
		echo "✅ Default inventory created successfully"; \
		echo "Contents:"; \
		cat ansible/inventory | head -10; \
	else \
		echo "❌ Default inventory creation failed"; \
	fi
	@echo ""
	@echo "Test 2: Migration inventory generation..."
	@$(MAKE) inventory SOURCE=balthasar TARGET=raspberrypi > /dev/null 2>&1
	@if [ -f ansible/inventory ]; then \
		echo "✅ Migration inventory created successfully"; \
		echo "Contents:"; \
		cat ansible/inventory | head -10; \
	else \
		echo "❌ Migration inventory creation failed"; \
	fi
	@echo ""
	@echo "Test 3: Tailscale status check..."
	@if command -v tailscale >/dev/null 2>&1; then \
		tailscale status | head -5; \
		echo "✅ Tailscale available"; \
	else \
		echo "⚠️  Tailscale not installed (expected in development)"; \
	fi
	@echo ""
	@echo "Test 4: Ansible availability..."
	@if command -v ansible >/dev/null 2>&1; then \
		ansible --version | head -1; \
		echo "✅ Ansible available"; \
	else \
		echo "❌ Ansible not available"; \
	fi
	@echo ""
	@echo "Test 5: Check migrate role structure..."
	@if [ -d ansible/playbooks/roles/migrate ]; then \
		echo "✅ Migrate role directory exists"; \
		ls -la ansible/playbooks/roles/migrate/; \
	else \
		echo "❌ Migrate role directory missing"; \
	fi
	@echo ""
	@echo "Test 6: README and Makefile consistency check..."
	@echo "README commands found:"
	@grep -n "make " ansible/playbooks/roles/migrate/README.md | head -5
	@echo ""
	@echo "Makefile targets available:"
	@$(MAKE) help | grep -E "(inventory|migrate)"
	@echo ""
	@echo "=== Test Summary ==="
	@echo "✅ = Pass, ❌ = Fail, ⚠️ = Warning"
	@echo ""
	@echo "To perform actual migration:"
	@echo "1. make migrate SOURCE=balthasar TARGET=raspberrypi"
	@echo "2. Ensure both hosts are accessible via Tailscale"
	@echo "3. Verify /opt/minio/secrets.yml exists on both hosts"

transfer:
	@echo "Transfer complete system: export from source and import to destination..."
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/export.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit destination ansible/playbooks/import.yml --ask-become-pass

provision:
	@echo "Running provision playbooks..."
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/common.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/security.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/modsecurity-nginx.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/monitoring.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/minio.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/misskey.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/ai.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/searxng.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/matrix.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/jitsi.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/vikunja.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/cryptpad.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/outline.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/uptime.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/deeplx.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/mcaptcha.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/ctfd.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/impostor.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/minecraft.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/neo-quesdon.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/lemmy.yml --ask-become-pass

backup:
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/misskey-backup.yml --ask-become-pass
	@ansible-playbook -i ansible/inventory --limit source ansible/playbooks/borgbackup.yml --ask-become-pass

update:
	@echo "Updating Misskey (Branch: $(MISSKEY_BRANCH))..."
	@cd $(MISSKEY_DIR) && sudo docker-compose down
	@cd $(MISSKEY_DIR) && sudo git stash || true
	@cd $(MISSKEY_DIR) && sudo git checkout $(MISSKEY_BRANCH) && sudo git pull origin $(MISSKEY_BRANCH)
	@cd $(MISSKEY_DIR) && sudo git submodule update --init
	@cd $(MISSKEY_DIR) && sudo git stash pop || true
	@cd $(MISSKEY_DIR) && sudo COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build --no-cache --build-arg TAG=misskey_web:$(TIMESTAMP)
	@cd $(MISSKEY_DIR) && sudo docker tag misskey_web:latest misskey_web:$(TIMESTAMP)
	@cd $(MISSKEY_DIR) && sudo docker compose stop && sudo docker compose up -d

help:
	@echo "Available targets:"
	@echo "  all           - Install, clone, setup, provision, and backup"
	@echo "  install       - Update and install necessary packages"
	@echo "  inventory     - Create Ansible inventory (supports SOURCE/TARGET for migration)"
	@echo "  clone         - Clone the repositories if they don't exist"
	@echo "  provision     - Provision the server using Ansible"
	@echo "  backup        - Run the backup playbook"
	@echo "  update        - Update Misskey and rebuild Docker images"
	@echo ""
	@echo "Migration commands:"
	@echo "  migrate       - Migrate MinIO data with encryption"
	@echo "  test          - Test migration system functionality"
	@echo "  transfer      - Transfer complete system using export/import playbooks"
	@echo ""
	@echo "Migration examples:"
	@echo "  make migrate SOURCE=balthasar TARGET=raspberrypi"
	@echo "  make inventory SOURCE=balthasar TARGET=raspberrypi"
	@echo "  make test             # Test migration system"