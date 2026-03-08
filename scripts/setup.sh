#!/usr/bin/env bash
# =============================================================================
# setup.sh — First-time setup for uye-mail
# Run once after cloning the repo, before starting containers.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

echo ""
echo "=== UYE Mail Server — First-time Setup ==="
echo ""

# --- Check prerequisites -----------------------------------------------------

command -v docker >/dev/null 2>&1  || error "docker not found. Install Docker Desktop or Docker Engine."
command -v docker compose version >/dev/null 2>&1 || error "docker compose v2 not found."

# --- .env file ---------------------------------------------------------------

if [[ ! -f "$ROOT_DIR/.env" ]]; then
    warn ".env not found. Copying from .env.example..."
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    warn "Edit .env with your values before starting containers."
    echo ""
fi

# --- Data directories (gitignored, must exist before containers start) -------

info "Creating data directories..."
mkdir -p \
    "$ROOT_DIR/data/mail" \
    "$ROOT_DIR/data/mail-state" \
    "$ROOT_DIR/data/mail-logs" \
    "$ROOT_DIR/data/roundcube"

# --- Config dir sanity check -------------------------------------------------

if [[ ! -d "$ROOT_DIR/config/docker-mailserver" ]]; then
    error "config/docker-mailserver directory missing. Is the repo intact?"
fi

info "Setup complete."
echo ""
echo "  Next steps:"
echo ""
echo "  1. Edit .env with your domain, SendGrid API key, and passwords."
echo ""
echo "  2. Start the development environment:"
echo "       make dev"
echo ""
echo "  3. Create your first mailbox:"
echo "       make add-account e=user@yourdomain.com p=password"
echo ""
echo "  4. Generate DKIM keys (do once, then add DNS record):"
echo "       make gen-dkim"
echo "       make dkim-record"
echo ""
echo "  5. See README.md for the full list of DNS records to add."
echo ""
