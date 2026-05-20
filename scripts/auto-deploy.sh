#!/bin/bash
# Auto-deploy: polls GHCR every minute, restarts only services whose images changed.
# Install:
#   cp scripts/auto-deploy.sh /opt/alfasente/auto-deploy.sh
#   chmod +x /opt/alfasente/auto-deploy.sh
#   echo "* * * * * root /opt/alfasente/auto-deploy.sh >> /var/log/alfasente-deploy.log 2>&1" \
#     >> /etc/cron.d/alfasente-deploy
set -e
cd /opt/alfasente

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Snapshot current image digests — changes when GHCR has a newer push
BEFORE=$(docker compose images --format json 2>/dev/null | md5sum)

# Pull latest images (quiet — only prints on actual download)
docker compose pull -q 2>/dev/null

AFTER=$(docker compose images --format json 2>/dev/null | md5sum)

if [ "$BEFORE" != "$AFTER" ]; then
    echo "[$TIMESTAMP] New images detected — redeploying"
    docker compose up -d 2>&1
    echo "[$TIMESTAMP] Redeployment complete"
fi
