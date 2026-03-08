#!/usr/bin/env bash
# =============================================================================
# add-account.sh — Add a virtual mailbox to docker-mailserver
# Usage: ./scripts/add-account.sh user@example.com [password]
#        make add-account e=user@example.com p=password
# =============================================================================
set -euo pipefail

EMAIL="${1:-}"
PASSWORD="${2:-}"

if [[ -z "$EMAIL" ]]; then
    echo "Usage: $0 <email> [password]"
    echo "       make add-account e=user@example.com p=password"
    exit 1
fi

# Prompt securely if password not provided as argument
if [[ -z "$PASSWORD" ]]; then
    read -rsp "Password for ${EMAIL}: " PASSWORD
    echo ""
    read -rsp "Confirm password: " PASSWORD_CONFIRM
    echo ""
    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
        echo "Error: passwords do not match." >&2
        exit 1
    fi
fi

# Check the mailserver container is running
if ! docker compose ps mailserver --status running 2>/dev/null | grep -q "running"; then
    echo "Error: mailserver container is not running. Start it first with 'make dev' or 'make prod'." >&2
    exit 1
fi

docker compose exec mailserver setup email add "$EMAIL" "$PASSWORD"
echo "Mailbox created: $EMAIL"
