# =============================================================================
# UYE Mail Server — Makefile
# =============================================================================

COMPOSE_DEV  = docker compose -f docker-compose.yml -f docker-compose.dev.yml
COMPOSE_PROD = docker compose -f docker-compose.yml -f docker-compose.prod.yml
COMPOSE      = docker compose

.PHONY: help dev dev-build prod down down-v logs \
        add-account del-account list-accounts passwd \
        gen-dkim dkim-record \
        setup shell rspamd-shell \
        ps pull

# Default target
help:
	@echo ""
	@echo "  UYE Mail Server"
	@echo ""
	@echo "  Environment"
	@echo "    make dev              Start in development mode (Mailpit, plain HTTP)"
	@echo "    make prod             Start in production mode (SendGrid, TLS)"
	@echo "    make down             Stop all containers (keep volumes)"
	@echo "    make down-v           Stop all containers and remove volumes"
	@echo "    make ps               Show container status"
	@echo "    make pull             Pull latest images"
	@echo ""
	@echo "  Logs"
	@echo "    make logs             Tail logs for all services"
	@echo "    make logs s=mailserver  Tail logs for a specific service"
	@echo ""
	@echo "  Account management"
	@echo "    make add-account e=user@example.com p=password"
	@echo "    make del-account e=user@example.com"
	@echo "    make list-accounts"
	@echo "    make passwd e=user@example.com p=newpassword"
	@echo ""
	@echo "  DKIM"
	@echo "    make gen-dkim         Generate DKIM keys (run once per domain)"
	@echo "    make dkim-record      Print the DNS TXT record to add"
	@echo ""
	@echo "  Misc"
	@echo "    make setup            First-time setup wizard"
	@echo "    make shell            Open shell inside mailserver"
	@echo "    make rspamd-shell     Open shell inside Rspamd (via mailserver)"
	@echo ""

# ---------------------------------------------------------------------------
# Environment management
# ---------------------------------------------------------------------------

dev:
	@$(COMPOSE_DEV) up -d
	@echo ""
	@echo "  Dev environment started:"
	@echo "    Roundcube  → http://localhost:$${HTTP_ROUNDCUBE_PORT:-8080}"
	@echo "    Mailpit    → http://localhost:$${HTTP_MAILPIT_PORT:-8025}"
	@echo "    Rspamd UI  → http://localhost:$${RSPAMD_PORT:-11334}"
	@echo ""

dev-build:
	@$(COMPOSE_DEV) up -d --build

prod:
	@$(COMPOSE_PROD) up -d

down:
	@$(COMPOSE) down

down-v:
	@$(COMPOSE) down -v

ps:
	@$(COMPOSE) ps

pull:
	@$(COMPOSE) pull

# ---------------------------------------------------------------------------
# Logs  (make logs s=roundcube)
# ---------------------------------------------------------------------------

logs:
	@$(COMPOSE) logs -f $(s)

# ---------------------------------------------------------------------------
# Account management
# ---------------------------------------------------------------------------

add-account:
	@test -n "$(e)" || (echo "Usage: make add-account e=user@domain.com p=password" && exit 1)
	@bash scripts/add-account.sh "$(e)" "$(p)"

del-account:
	@test -n "$(e)" || (echo "Usage: make del-account e=user@domain.com" && exit 1)
	@$(COMPOSE) exec mailserver setup email del "$(e)"

list-accounts:
	@$(COMPOSE) exec mailserver setup email list

passwd:
	@test -n "$(e)" || (echo "Usage: make passwd e=user@domain.com p=newpassword" && exit 1)
	@$(COMPOSE) exec mailserver setup email update "$(e)" "$(p)"

# ---------------------------------------------------------------------------
# DKIM
# ---------------------------------------------------------------------------

gen-dkim:
	@bash scripts/gen-dkim.sh

dkim-record:
	@echo "DKIM DNS record for your domain:"
	@$(COMPOSE) exec mailserver cat /tmp/docker-mailserver/rspamd/dkim/*.txt 2>/dev/null \
		|| echo "No DKIM key found. Run: make gen-dkim"

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

setup:
	@bash scripts/setup.sh

shell:
	@$(COMPOSE) exec mailserver bash

rspamd-shell:
	@$(COMPOSE) exec mailserver rspamadm shell
