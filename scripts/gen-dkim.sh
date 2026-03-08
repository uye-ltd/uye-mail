#!/usr/bin/env bash
# =============================================================================
# gen-dkim.sh — Generate DKIM signing keys via docker-mailserver / Rspamd
#
# Run once per domain. After running, add the printed TXT record to DNS.
# The private key is stored in data/mail-state (gitignored — back it up).
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load MAIL_DOMAIN from .env
if [[ -f "$ROOT_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    set -a; source "$ROOT_DIR/.env"; set +a
fi

DOMAIN="${MAIL_DOMAIN:-}"

if [[ -z "$DOMAIN" ]]; then
    echo "Error: MAIL_DOMAIN is not set in .env" >&2
    exit 1
fi

# Check the mailserver container is running
if ! docker compose ps mailserver --status running 2>/dev/null | grep -q "running"; then
    echo "Error: mailserver container is not running. Start it first with 'make dev' or 'make prod'." >&2
    exit 1
fi

echo "Generating DKIM key for domain: $DOMAIN"
echo ""

docker compose exec mailserver setup config dkim domain "$DOMAIN"

echo ""
echo "========================================================"
echo "  DKIM key generated. Add this TXT record to DNS:"
echo "========================================================"
echo ""

# DMS v14 stores the DNS record in the dkim directory as a .txt file
docker compose exec mailserver bash -c \
    "find /tmp/docker-mailserver/rspamd/dkim -name '*.txt' -exec cat {} \;" \
    2>/dev/null || {
    echo "(Could not auto-print record. Check inside the container:)"
    echo "  docker compose exec mailserver find /tmp/docker-mailserver/rspamd/dkim -name '*.txt'"
}

echo ""
echo "Also remember to add/verify these records in DNS:"
echo ""
echo "  Type  Name                     Value"
echo "  MX    ${DOMAIN}.               mail.${DOMAIN}  (priority 10)"
echo "  TXT   ${DOMAIN}.               v=spf1 include:sendgrid.net ~all"
echo "  TXT   _dmarc.${DOMAIN}.        v=DMARC1; p=quarantine; rua=mailto:postmaster@${DOMAIN}"
echo ""
echo "See README.md for the full DNS setup guide."
