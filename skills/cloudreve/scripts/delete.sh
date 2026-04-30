#!/usr/bin/env bash
# Delete a file from Cloudreve v4
# Usage: delete.sh <CLOUDREVE_URL> <TOKEN> <FILE_URI>
# Handles lock conflicts (40073) with automatic retry.

set -euo pipefail

CLOUDREVE_URL="${1:?Usage: delete.sh <URL> <TOKEN> <FILE_URI>}"
TOKEN="${2:?Missing TOKEN}"
FILE_URI="${3:?Missing FILE_URI}"

log() { echo "$@" >&2; }

MAX_RETRIES=3
RETRY_DELAY=3

for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    RESPONSE=$(curl -sf -X DELETE \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import json, sys
print(json.dumps({'uris': [sys.argv[1]]}))
" "$FILE_URI")" \
      "${CLOUDREVE_URL}/api/v4/file") || { log "ERROR: curl failed"; exit 1; }

    CODE=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('code',-1))")

    if [ "$CODE" = "0" ]; then
        log "OK: Deleted -> $FILE_URI"
        exit 0
    elif [ "$CODE" = "40073" ]; then
        if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
            log "WARN: Lock conflict (40073), retrying in ${RETRY_DELAY}s... (attempt $ATTEMPT/$MAX_RETRIES)"
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
        else
            log "ERROR: Delete failed after $MAX_RETRIES attempts (code=40073: Lock conflict)"
            exit 1
        fi
    else
        MSG=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('msg','unknown'))")
        log "ERROR: Delete failed (code=$CODE): $MSG"
        exit 1
    fi
done
