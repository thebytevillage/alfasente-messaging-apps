# alfasente-messaging-apps

One-command deployment of the full Alfasente Messaging Platform stack.

All images are pulled from GHCR — no local builds required.

| Service | URL | Image |
|---|---|---|
| REST API | http://localhost:3000 | `ghcr.io/thebytevillage/messaging-platform-api:main` |
| Admin Portal | http://localhost:5174 | `ghcr.io/thebytevillage/alfasente-messaging-admin:main` |
| Customer Portal | http://localhost:5175 | `ghcr.io/thebytevillage/alfasente-messaging-portal:main` |
| Adminer (DB UI) | http://localhost:8080 | `adminer:latest` |

## Quick start

```bash
cp .env.example .env
# Fill in JWT_SECRET, ADMIN_JWT_SECRET, ENCRYPTION_KEY at minimum

docker compose up -d
```

## Pull latest images

```bash
docker compose pull
docker compose up -d
```

## Pin to a specific release

Edit `docker-compose.yml` and change the `:main` tag to a version tag, e.g. `:v1.2.0`.

## Repos

- API: https://github.com/thebytevillage/messaging-platform-api
- Admin: https://github.com/thebytevillage/alfasente-messaging-admin
- Portal: https://github.com/thebytevillage/alfasente-messaging-portal
