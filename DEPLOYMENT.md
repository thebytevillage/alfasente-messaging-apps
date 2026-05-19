# Alfasente Messaging Platform — Deployment Guide

This repo contains the production Docker Compose stack. All images are pulled from GHCR — no local builds required on the server.

**Services and ports exposed to host:**

| Service | Port | Hostname |
|---|---|---|
| API | 3000 | `messagingapi.alfasente.com` |
| Customer portal | 5173 | `messaging.alfasente.com` / `messaging-dev.alfasente.com` |
| Admin portal | 5174 | `messaging-admin.alfasente.com` |

SSL is terminated by the host's Nginx — Docker runs HTTP only.

---

## Step 1 — DNS records

In your DNS provider, create an **A record** for each subdomain pointing to your server's public IP:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `messaging` | `YOUR_SERVER_IP` | 300 |
| A | `messagingapi` | `YOUR_SERVER_IP` | 300 |
| A | `messaging-admin` | `YOUR_SERVER_IP` | 300 |
| A | `messaging-api` | `YOUR_SERVER_IP` | 300 |
| A | `messaging-dev` | `YOUR_SERVER_IP` | 300 |

Wait for propagation (usually 5–30 min), then verify:

```bash
dig messaging.alfasente.com +short
# should return YOUR_SERVER_IP
```

---

## Step 2 — Server setup (one-time)

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Nginx and Certbot
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Verify
docker --version
nginx -v
```

---

## Step 3 — Clone this repo

```bash
sudo mkdir -p /opt/alfasente
sudo chown $USER:$USER /opt/alfasente
git clone https://github.com/thebytevillage/alfasente-messaging-apps.git /opt/alfasente
cd /opt/alfasente
```

---

## Step 4 — Configure environment

```bash
cp .env.example .env
nano .env
```

Generate the required secrets:

```bash
# ENCRYPTION_KEY — exactly 64 hex chars
openssl rand -hex 32

# JWT_SECRET and ADMIN_JWT_SECRET — at least 32 chars each
openssl rand -base64 32
openssl rand -base64 32

# POSTGRES_PASSWORD
openssl rand -base64 24
```

Minimum required values before starting:

```env
POSTGRES_PASSWORD=<generated>
JWT_SECRET=<generated>
ADMIN_JWT_SECRET=<generated>
ENCRYPTION_KEY=<generated — 64 hex chars>
APP_URL=https://messaging.alfasente.com
```

---

## Step 5 — Start the Docker stack

```bash
cd /opt/alfasente

# Pull latest images
docker compose pull

# Start all services
docker compose up -d

# Watch startup — wait for "Server listening on..."
docker compose logs -f api
```

Verify everything is healthy:

```bash
docker compose ps
# All services should show "healthy" or "running"

curl http://localhost:3000/health
# {"status":"ok","timestamp":"..."}
```

---

## Step 6 — Configure Nginx (HTTP first)

```bash
sudo nano /etc/nginx/sites-available/alfasente
```

Paste the following — **HTTP only for now**, SSL is added in Step 7:

```nginx
# Customer portal + developer docs
server {
    listen 80;
    server_name messaging.alfasente.com messaging-dev.alfasente.com;

    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /openapi.json { proxy_pass http://127.0.0.1:3000; }
    location /reference    { proxy_pass http://127.0.0.1:3000; }
    location / {
        proxy_pass http://127.0.0.1:5173;
        proxy_set_header Host $host;
    }
}

# Admin portal
server {
    listen 80;
    server_name messaging-admin.alfasente.com;

    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location / {
        proxy_pass http://127.0.0.1:5174;
        proxy_set_header Host $host;
    }
}

# Direct API access
server {
    listen 80;
    server_name messagingapi.alfasente.com messaging-api.alfasente.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/alfasente /etc/nginx/sites-enabled/alfasente
sudo nginx -t
sudo systemctl reload nginx
```

Verify over HTTP before adding SSL:

```bash
curl http://messaging.alfasente.com/api/v1/health
# {"status":"ok"}
```

---

## Step 7 — SSL certificates (Let's Encrypt)

```bash
sudo certbot --nginx \
  -d messaging.alfasente.com \
  -d messaging-admin.alfasente.com \
  -d messagingapi.alfasente.com \
  -d messaging-api.alfasente.com \
  -d messaging-dev.alfasente.com \
  --email your@email.com \
  --agree-tos \
  --no-eff-email
```

Certbot automatically updates the Nginx config and sets up auto-renewal. Verify:

```bash
curl https://messaging.alfasente.com/api/v1/health
# {"status":"ok"}

# Test auto-renewal
sudo certbot renew --dry-run
```

---

## Step 8 — Seed the database

The migration runs automatically on startup via the `migrate` container. To seed initial data (channels, pricing, credit packages, and credentials), use an SSH tunnel:

```bash
# Terminal 1 — tunnel the DB port
ssh -L 5432:localhost:5432 user@YOUR_SERVER_IP

# Terminal 2 — run the interactive seed script from the API repo
cd messaging-platform-api
pnpm prisma:seed
```

The seed script walks you through:
- Channel records and default pricing
- WhatsApp (Meta) credentials
- Resend email credentials
- Alfasente Pay credentials

---

## Step 9 — Register the Meta WhatsApp webhook

Once the API is live at `https://messagingapi.alfasente.com`:

1. Open **Meta Developer Dashboard → WhatsApp → Configuration → Webhook → Edit**
2. **Callback URL:** `https://messagingapi.alfasente.com/api/v1/callbacks/whatsapp:meta-cloud`
3. **Verify token:** the value you set for `META_WEBHOOK_VERIFY_TOKEN` in `.env`
4. **Subscriptions:** tick `messages` and `message_status_updates`
5. Click **Verify and Save** — Meta hits the endpoint immediately to confirm ownership

---

## Updating to a new release

```bash
cd /opt/alfasente
git pull
docker compose pull
docker compose up -d
```

Migration runs automatically on every startup via the `migrate` service.

---

## Useful commands

```bash
# View logs
docker compose logs -f api
docker compose logs -f customer-portal
docker compose logs -f admin-portal

# Restart a single service
docker compose restart api

# Check all service health
docker compose ps

# Pull and redeploy a single service
docker compose pull api && docker compose up -d api

# Enable DB admin UI (127.0.0.1 only — use SSH tunnel to access)
docker compose --profile admin up -d adminer
# SSH tunnel: ssh -L 8080:localhost:8080 user@YOUR_SERVER_IP
# Then open: http://localhost:8080

# Stop everything
docker compose down

# Stop and remove volumes (WARNING: deletes all data)
docker compose down -v
```

---

## Domain summary

| URL | What it serves |
|---|---|
| `https://messaging.alfasente.com` | Customer portal (dashboard + landing page) |
| `https://messaging.alfasente.com/docs` | Developer documentation |
| `https://messaging-dev.alfasente.com` | Same as above (alias) |
| `https://messagingapi.alfasente.com` | API direct access |
| `https://messagingapi.alfasente.com/openapi.json` | OpenAPI spec |
| `https://messagingapi.alfasente.com/reference` | Interactive API reference (Scalar) |
| `https://messaging-api.alfasente.com` | API dev proxy (alias) |
| `https://messaging-admin.alfasente.com` | Admin portal |
