#!/usr/bin/env bash
# Upload a file to Cloudreve v4
# Usage: upload.sh <CLOUDREVE_URL> <TOKEN> <LOCAL_FILE> [REMOTE_NAME] [REMOTE_DIR]
# Docs: https://docs.cloudreve.org/zh/api/upload

set -euo pipefail

CLOUDREVE_URL="${1:?Missing URL}"; TOKEN="${2:?Missing TOKEN}"
LOCAL_FILE="${3:?Missing FILE}"; REMOTE_NAME="${4:-$(basename "$LOCAL_FILE")}"
REMOTE_DIR="${5:-cloudreve://my}"

[ -f "$LOCAL_FILE" ] || { echo "ERROR: File not found: $LOCAL_FILE" >&2; exit 1; }

FILE_SIZE=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null)
TARGET_URI="${REMOTE_DIR}/${REMOTE_NAME}"

log() { echo "$@" >&2; }

log "Uploading: $LOCAL_FILE ($FILE_SIZE bytes) -> $TARGET_URI"

# ── Step 1: Create upload session (PUT /api/v4/file/upload) ──
create_session() {
    curl -sf -X PUT \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "
import json, sys
print(json.dumps({'uri': sys.argv[1], 'size': int(sys.argv[2])}))
" "$TARGET_URI" "$FILE_SIZE")" \
        "${CLOUDREVE_URL}/api/v4/file/upload"
}

SESSION_RESP=$(create_session) || { log "ERROR: Failed to create upload session"; exit 1; }

# Parse response — handle both success and error cases
PARSED=$(python3 - "$SESSION_RESP" << 'PYEOF'
import json, sys
data = json.loads(sys.argv[1])
code = data.get("code", -1)
if code == 0:
    d = data["data"]
    print(f'OK|{d["session_id"]}|{d["chunk_size"]}')
elif code == 40004:
    # Object existed — need to delete first then retry
    print(f'EXISTS|{code}|{data.get("msg","")}')
else:
    print(f'FAIL|{code}|{data.get("msg","unknown")}')
PYEOF
)

IFS='|' read -r STATUS VAL1 VAL2 <<< "$PARSED"

if [ "$STATUS" = "EXISTS" ]; then
    log "File exists, attempting to delete and re-upload..."
    
    # Delete the existing file — retry up to 3 times for lock conflicts
    DEL_RETRIES=3
    DEL_DELAY=3
    DEL_OK=false
    
    for DEL_ATTEMPT in $(seq 1 $DEL_RETRIES); do
        DEL_RESP=$(curl -sf -X DELETE \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(python3 -c "
import json, sys
print(json.dumps({'uris': [sys.argv[1]]}))
" "$TARGET_URI")" \
            "${CLOUDREVE_URL}/api/v4/file") || true
        
        DEL_CODE=$(echo "$DEL_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('code',-1))" 2>/dev/null || echo "-1")
        
        if [ "$DEL_CODE" = "0" ]; then
            log "Deleted existing file."
            DEL_OK=true
            break
        elif [ "$DEL_CODE" = "40073" ]; then
            if [ "$DEL_ATTEMPT" -lt "$DEL_RETRIES" ]; then
                log "WARN: File locked (40073), waiting ${DEL_DELAY}s... (attempt $DEL_ATTEMPT/$DEL_RETRIES)"
                sleep $DEL_DELAY
                DEL_DELAY=$((DEL_DELAY * 2))
            else
                log "ERROR: Cannot delete locked file after $DEL_RETRIES attempts. Try a different filename."
                exit 1
            fi
        else
            log "WARN: Delete returned code $DEL_CODE, attempting upload anyway..."
            DEL_OK=true
            break
        fi
    done
    
    if [ "$DEL_OK" = true ]; then
        log "Creating new upload session..."
    fi
    
    # Retry session creation
    SESSION_RESP=$(create_session) || { log "ERROR: Failed to create upload session after delete"; exit 1; }
    
    PARSED=$(python3 - "$SESSION_RESP" << 'PYEOF'
import json, sys
data = json.loads(sys.argv[1])
code = data.get("code", -1)
if code == 0:
    d = data["data"]
    print(f'OK|{d["session_id"]}|{d["chunk_size"]}')
else:
    print(f'FAIL|{code}|{data.get("msg","unknown")}')
PYEOF
 )
    IFS='|' read -r STATUS VAL1 VAL2 <<< "$PARSED"
fi

if [ "$STATUS" != "OK" ]; then
    log "ERROR: Session creation failed (code=$VAL1): $VAL2"
    exit 1
fi

SESSION_ID="$VAL1"
CHUNK_SIZE="$VAL2"

log "Session: $SESSION_ID, chunk_size: $CHUNK_SIZE"

# ── Step 2: Upload chunks ──
CHUNK_INDEX=0
OFFSET=0

while [ "$OFFSET" -lt "$FILE_SIZE" ]; do
    REMAINING=$((FILE_SIZE - OFFSET))
    THIS_CHUNK=$((REMAINING < CHUNK_SIZE ? REMAINING : CHUNK_SIZE))

    log "Uploading chunk $CHUNK_INDEX ($THIS_CHUNK bytes at offset $OFFSET)..."

    # Extract chunk and upload via stdin pipe (avoids temp files)
    UPLOAD_RESP=$(dd if="$LOCAL_FILE" bs=1 skip="$OFFSET" count="$THIS_CHUNK" 2>/dev/null \
      | curl -sf -X POST \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/octet-stream" \
          --data-binary @- \
          "${CLOUDREVE_URL}/api/v4/file/upload/${SESSION_ID}/${CHUNK_INDEX}") || {
        log "ERROR: Chunk $CHUNK_INDEX upload failed (curl error)"
        exit 1
    }

    UPLOAD_CODE=$(echo "$UPLOAD_RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("code",-1))' 2>/dev/null || echo "-1")

    if [ "$UPLOAD_CODE" != "0" ]; then
        UPLOAD_MSG=$(echo "$UPLOAD_RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("msg","unknown"))' 2>/dev/null || echo "unknown")
        log "ERROR: Chunk $CHUNK_INDEX upload failed (code=$UPLOAD_CODE): $UPLOAD_MSG"
        exit 1
    fi

    OFFSET=$((OFFSET + THIS_CHUNK))
    CHUNK_INDEX=$((CHUNK_INDEX + 1))
done

log "OK: Uploaded -> $TARGET_URI ($CHUNK_INDEX chunk(s))"
