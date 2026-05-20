#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd /opt/alfasente

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

OUTPUT=$(docker compose pull 2>&1)

if echo "$OUTPUT" | grep -q "Pulled"; then
    echo "[$TIMESTAMP] New images detected -- redeploying"
    docker compose up -d 2>&1
    echo "[$TIMESTAMP] Redeployment complete"
fi
