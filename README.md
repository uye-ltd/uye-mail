# uye-mail

Dockerized mail server for the UYE microservice platform.

**Stack:** docker-mailserver (Postfix + Dovecot) · Rspamd · SendGrid relay · Roundcube

---

## Architecture

```
Internet
   │
   ▼
[uye-edge nginx] ──HTTP(S)──► [Roundcube :80]   (webmail)
                              [Rspamd UI :11334] (spam admin)
                                      │
                                 [mail-net]
                                      │
                              [docker-mailserver]
                              Postfix + Dovecot + Rspamd
                                      │
                               SMTP/IMAP ports
                              (exposed directly on host)
                                      │
                              [SendGrid relay]
                              smtp.sendgrid.net:587

Your Go/Python services ──SMTP:587──► mailserver ──► SendGrid ──► internet
```

**Networks:**
- `mail-net` — internal bridge between mailserver and Roundcube
- `uye-net` — shared with uye-edge; nginx picks up Roundcube and Rspamd UI here

---

## Quick Start

### 1. Initial setup

```bash
# Clone and run setup
bash scripts/setup.sh

# Edit .env with your values
cp .env.example .env
$EDITOR .env
```

### 2. Start in development mode

```bash
make dev
```

| Service     | URL                          |
|-------------|------------------------------|
| Roundcube   | http://localhost:8080        |
| Mailpit     | http://localhost:8025        |
| Rspamd UI   | http://localhost:11334       |

In dev, **all outbound mail is captured by Mailpit** — no real emails are sent.

### 3. Create a mailbox

```bash
make add-account e=user@yourdomain.com p=yourpassword
make list-accounts
```

---

## DNS Setup (Production)

All records below are required for reliable inbox delivery (SPF, DKIM, DMARC).

### MX — incoming mail routing

| Type | Name          | Value              | Priority |
|------|---------------|--------------------|----------|
| MX   | example.com.  | mail.example.com.  | 10       |

### A — mail server IP

| Type | Name               | Value         |
|------|--------------------|---------------|
| A    | mail.example.com.  | YOUR_SERVER_IP |

### SPF — authorize SendGrid to send on your behalf

| Type | Name         | Value                              |
|------|--------------|------------------------------------|
| TXT  | example.com. | `v=spf1 include:sendgrid.net ~all` |

### DKIM — cryptographic signature

1. Generate keys (mailserver must be running):
   ```bash
   make gen-dkim
   make dkim-record   # prints the TXT record value
   ```
2. Add the printed TXT record to DNS (selector is typically `mail._domainkey`).

| Type | Name                          | Value                     |
|------|-------------------------------|---------------------------|
| TXT  | mail._domainkey.example.com.  | `v=DKIM1; k=rsa; p=...`  |

### DMARC — policy for failed auth

| Type | Name                 | Value                                                        |
|------|----------------------|--------------------------------------------------------------|
| TXT  | _dmarc.example.com.  | `v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com` |

### PTR (Reverse DNS)

Set a PTR record for your server's IP → `mail.example.com` with your hosting provider. This is critical for inbox delivery and cannot be done in your domain's DNS panel — it must be set at the VPS/server level.

---

## Production Deployment

### Prerequisites

- TLS certificates for `mail.example.com` (managed by uye-edge / certbot)
- `UYE_NETWORK` in `.env` matching the network name in uye-edge
- SendGrid API key with "Mail Send" permission

### Deploy

```bash
make prod
```

### nginx configuration in uye-edge

Add these upstreams in your uye-edge nginx config:

```nginx
# Roundcube webmail
upstream roundcube {
    server uye-mail-roundcube:80;
}

server {
    listen 443 ssl;
    server_name mail.example.com;
    location / {
        proxy_pass http://roundcube;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Rspamd UI (restrict access — not public)
upstream rspamd {
    server uye-mail-mailserver:11334;
}
```

Container names follow the pattern `${COMPOSE_PROJECT_NAME}-<service>`.

---

## Account Management

```bash
# Add mailbox
make add-account e=user@example.com p=password

# Delete mailbox
make del-account e=user@example.com

# List all mailboxes
make list-accounts

# Change password
make passwd e=user@example.com p=newpassword
```

---

## Connecting Microservices

Your Go and Python services connect to the mail server via SMTP on port 587.

See working examples in:
- `examples/go/smtp_client.go`
- `examples/python/smtp_client.py`

**Environment variables for your service:**

```env
SMTP_HOST=mailserver      # Docker service name (same network) or host IP
SMTP_PORT=587
SMTP_USERNAME=noreply@example.com
SMTP_PASSWORD=yourpassword
SMTP_FROM=noreply@example.com
SMTP_INSECURE=false       # true only in dev with self-signed certs
```

**Dev shortcut:** connect directly to Mailpit at `mailpit:1025` (no auth required) if your service is on the same Docker network (`uye-mail-mail-net-dev`).

---

## Rspamd Configuration

Spam thresholds and Bayes classifier settings are in:
- `config/rspamd/local.d/actions.conf` — score thresholds
- `config/rspamd/local.d/classifier-bayes.conf` — auto-learning settings

Access the web UI at `http://localhost:11334` (dev) with `RSPAMD_PASSWORD` from `.env`.

**Train spam/ham manually:**
```bash
# Mark a message as spam (provide the .eml file)
docker compose exec mailserver rspamc learn_spam < message.eml

# Mark a message as ham
docker compose exec mailserver rspamc learn_ham < message.eml
```

---

## Maintenance

```bash
# View logs
make logs
make logs s=mailserver

# Open a shell inside the mail server
make shell

# Check Postfix mail queue
docker compose exec mailserver postqueue -p

# Flush the queue (retry deferred mail)
docker compose exec mailserver postqueue -f

# Reload Postfix config without restart
docker compose exec mailserver postfix reload
```

---

## Troubleshooting

**Emails landing in spam**
1. Verify SPF, DKIM, and DMARC records with [mail-tester.com](https://www.mail-tester.com) or `dig TXT yourdomain.com`.
2. Confirm PTR/rDNS is set for your server IP.
3. Check Rspamd score: `docker compose exec mailserver rspamc symbols < message.eml`.

**Cannot receive mail**
1. Confirm MX record points to your server and port 25 is open (not blocked by your provider).
2. Check Postfix logs: `make logs s=mailserver`.

**DKIM not signing**
- Regenerate keys: `make gen-dkim`.
- Confirm the DNS TXT record matches exactly: `make dkim-record`.

**Roundcube login fails**
- Ensure the mailbox exists: `make list-accounts`.
- Check IMAP logs in `data/mail-logs/`.
