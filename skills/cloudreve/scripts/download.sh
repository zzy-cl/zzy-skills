#!/usr/bin/env bash
# Download a file from Cloudreve v4
# Usage: download.sh <CLOUDREVE_URL> <TOKEN> <FILE_URI> [LOCAL_PATH]

set -euo pipefail

CLOUDREVE_URL="${1:?Missing URL}"; TOKEN="${2:?Missing TOKEN}"
FILE_URI="${3:?Missing URI}"; LOCAL_PATH="${4:-.}"

# Step 1: Get signed download URL (POST /api/v4/file/url)
URL_RESP=$(curl -sf -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
print(json.dumps({'uris': [sys.argv[1]]}))
" "$FILE_URI")" \
  "${CLOUDREVE_URL}/api/v4/file/url")

# Parse response
DOWNLOAD_URL=$(python3 - "$URL_RESP" << 'PYEOF'
import json, sys
data = json.loads(sys.argv[1])
if data.get("code") != 0:
    print(data.get("msg", "err"), file=sys.stderr)
    sys.exit(1)
urls = data.get("data", {}).get("urls", [])
if not urls:
    print("No download URL returned", file=sys.stderr)
    sys.exit(1)
print(urls[0]["url"])
PYEOF
)

# Step 2: Determine output path
FILENAME=$(basename "$FILE_URI")
[ -d "$LOCAL_PATH" ] && OUTPUT="${LOCAL_PATH}/${FILENAME}" || OUTPUT="$LOCAL_PATH"

# Step 3: Download
[[ "$DOWNLOAD_URL" == http* ]] && FETCH_URL="$DOWNLOAD_URL" || FETCH_URL="${CLOUDREVE_URL}${DOWNLOAD_URL}"

if curl -sf -o "$OUTPUT" "$FETCH_URL"; then
    SIZE=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
    echo "OK: Downloaded -> $OUTPUT ($SIZE bytes)" >&2
else
    echo "ERROR: Download failed" >&2; rm -f "$OUTPUT"; exit 1
fi
