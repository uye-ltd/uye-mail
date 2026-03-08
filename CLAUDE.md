# CLAUDE.md — uye-mail

AI assistant context for this repository.

## What this repo is

Dockerized mail server for the UYE microservice platform. It handles both inbound and outbound email for `MAIL_DOMAIN` (configured in `.env`).

**Part of a larger system:**
- `uye-edge` (separate repo) — nginx reverse proxy that routes HTTP(S) to services on the shared `uye-net` Docker network.
- `uye-mail` (this repo) — mail server; web UIs attach to `uye-net`, SMTP/IMAP ports are exposed directly on the host.

## Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| MTA | Postfix (via docker-mailserver) | Sends and receives mail |
| IMAP | Dovecot (via docker-mailserver) | Mailbox access for clients |
| Anti-spam / DKIM / DMARC | Rspamd | Bundled in DMS v14 |
| Outbound relay | SendGrid (free, 100/day) | Dev: replaced by Mailpit |
| Webmail | Roundcube 1.6 | Exposed on `uye-net` for nginx |
| Email capture (dev) | Mailpit | Catches all outbound mail in dev |

## Key files

```
docker-compose.yml              Base service definitions
docker-compose.dev.yml          Dev overrides (Mailpit relay, plain HTTP, local uye-net)
docker-compose.prod.yml         Prod overrides (SendGrid, TLS, external uye-net, restart:always)
.env.example                    All configuration variables with documentation
Makefile                        All day-to-day commands (run `make` for help)
config/docker-mailserver/       Postfix config overrides (postfix-main.cf, etc.)
config/rspamd/local.d/          Rspamd tuning (thresholds, Bayes)
config/roundcube/config.inc.php Roundcube supplementary config
scripts/setup.sh                First-time setup
scripts/add-account.sh          Create a virtual mailbox
scripts/gen-dkim.sh             Generate DKIM keys + print DNS record
examples/go/smtp_client.go      SMTP client for Go services
examples/python/smtp_client.py  SMTP client for Python services
data/                           Runtime state (gitignored — never commit)
```

## Common commands

```bash
make dev                                # Start dev environment
make prod                               # Start prod environment
make logs s=mailserver                  # Tail logs for a service
make add-account e=user@domain.com p=pw # Add mailbox
make list-accounts                      # List mailboxes
make gen-dkim                           # Generate DKIM keys
make dkim-record                        # Print DNS TXT record
make shell                              # Shell into mailserver container
```

## Environment / configuration

All configuration is in `.env` (copy from `.env.example`). Key variables:

- `MAIL_HOSTNAME` — FQDN of the server (e.g. `mail.example.com`)
- `MAIL_DOMAIN` — email domain (e.g. `example.com`)
- `SENDGRID_API_KEY` — for outbound relay in prod
- `RSPAMD_PASSWORD` — Rspamd web UI password (plain text, DMS hashes it)
- `ROUNDCUBE_DES_KEY` — exactly 24 characters
- `UYE_NETWORK` — shared Docker network name (must match uye-edge)
- `TLS_CERT_PATH` / `TLS_KEY_PATH` — cert paths on host (prod only)

## Network topology

```
[uye-edge nginx]
      │ uye-net (external, shared)
      ├──► roundcube:80
      └──► mailserver:11334 (Rspamd UI, optional)

[mailserver] ◄──► [roundcube]   (mail-net, internal)

[mailserver] ports exposed on host:
  25   SMTP (inbound from internet)
  587  Submission (from microservices / Roundcube)
  465  SMTPS
  143  IMAP
  993  IMAPS
  11334 Rspamd UI (localhost-only in prod)
```

## Dev vs prod differences

| Aspect | Dev | Prod |
|--------|-----|------|
| Outbound relay | Mailpit (captures, no real send) | SendGrid |
| TLS | None (plain IMAP/SMTP internally) | SSL_TYPE=manual, certs from uye-edge |
| uye-net | Local bridge (no uye-edge needed) | External (owned by uye-edge) |
| Roundcube port | Exposed on host `:8080` | Via nginx on uye-net only |
| Rspamd port | Exposed on host `:11334` | `127.0.0.1:11334` only |
| Fail2ban | Disabled | Enabled |
| Log level | debug | warn |

## docker-mailserver (DMS) notes

- Version: `ghcr.io/docker-mailserver/docker-mailserver:14`
- DMS v14 uses **Rspamd** for spam filtering and **DKIM signing** (not OpenDKIM).
- Config files in `config/docker-mailserver/` are mounted at `/tmp/docker-mailserver/` and read by DMS at startup.
- `postfix-main.cf` in that directory is **appended** to Postfix's main.cf — do not duplicate DMS-managed settings.
- Rspamd local overrides go in `config/rspamd/local.d/` — DMS copies them on startup.
- Account management uses DMS's `setup email` CLI — do not edit `postfix-accounts.cf` by hand.
- DKIM keys live in `data/mail-state/` (gitignored) — back them up after generating.

## DNS records required for production

| Type | Name | Value |
|------|------|-------|
| A | mail.example.com | server IP |
| MX | example.com | mail.example.com (priority 10) |
| TXT | example.com | `v=spf1 include:sendgrid.net ~all` |
| TXT | mail._domainkey.example.com | `v=DKIM1; k=rsa; p=...` (from `make dkim-record`) |
| TXT | _dmarc.example.com | `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com` |
| PTR | server IP | mail.example.com (set at VPS level) |

## What NOT to change without careful thought

- Do not add services that require their own DB (keep it lean — SQLite for Roundcube is intentional).
- Do not expose Rspamd UI publicly without authentication (`RSPAMD_PASSWORD` is mandatory).
- Do not set `PERMIT_DOCKER=none` — it breaks container-to-container SMTP.
- Do not remove `stop_grace_period: 1m` on mailserver — Postfix needs time to flush its queue cleanly.
