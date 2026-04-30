#!/usr/bin/env bash
# List files in Cloudreve v4 directory
# Usage: list.sh <CLOUDREVE_URL> <TOKEN> [DIR_URI]
# Supports Cloudreve v4 file URI query parameters:
#   cloudreve://my?category=image  (images only)
#   cloudreve://my?name=report     (search by name)
#   cloudreve://my?type=file       (files only)
#   cloudreve://my?name=report&type=file&case_folding=true

set -euo pipefail

CLOUDREVE_URL="${1:?Usage: list.sh <URL> <TOKEN> [DIR_URI]}"
TOKEN="${2:?Missing TOKEN}"
DIR_URI="${3:-cloudreve://my}"

# URL-encode the URI
ENCODED_URI=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$DIR_URI")

RESPONSE=$(curl -sf -H "Authorization: Bearer $TOKEN" \
  "${CLOUDREVE_URL}/api/v4/file?uri=${ENCODED_URI}")

python3 - "$RESPONSE" << 'PYEOF'
import json, sys

data = json.loads(sys.argv[1])
if data.get("code") != 0:
    print(f"ERROR: {data.get('msg', 'unknown')}", file=sys.stderr)
    sys.exit(1)

files = data.get("data", {}).get("files", [])
if not files:
    print("(empty directory)")
    sys.exit(0)

for f in files:
    ftype = "dir" if f["type"] == 1 else "   "
    name = f["name"]
    size = f.get("size", 0)
    if f["type"] == 1:
        size_str = "-"
    elif size > 1073741824:
        size_str = f"{size/1073741824:.1f}G"
    elif size > 1048576:
        size_str = f"{size/1048576:.1f}M"
    elif size > 1024:
        size_str = f"{size/1024:.0f}K"
    else:
        size_str = f"{size}B"
    print(f"[{ftype}] {size_str:>8s}  {name}  ({f['path']})")
PYEOF
