#!/usr/bin/env bash
# Show Cloudreve v4 storage usage
# Usage: storage.sh <CLOUDREVE_URL> <TOKEN>

set -euo pipefail

CLOUDREVE_URL="${1:?Usage: storage.sh <URL> <TOKEN>}"
TOKEN="${2:?Missing TOKEN}"

RESPONSE=$(curl -sf -H "Authorization: Bearer $TOKEN" \
  "${CLOUDREVE_URL}/api/v4/user/capacity")

python3 - "$RESPONSE" << 'PYEOF'
import json, sys
data = json.loads(sys.argv[1])
if data.get("code") != 0:
    print(f"ERROR: {data.get('msg', 'unknown')}", file=sys.stderr)
    sys.exit(1)
cap = data.get("data", {})
total = cap.get("total", 0)
used = cap.get("used", 0)
free = total - used
def fmt(b):
    if b > 1073741824: return f"{b/1073741824:.2f} GB"
    if b > 1048576: return f"{b/1048576:.1f} MB"
    if b > 1024: return f"{b/1024:.1f} KB"
    return f"{b} B"
pct = (used / total * 100) if total > 0 else 0
print(f"Total: {fmt(total)}")
print(f"Used:  {fmt(used)} ({pct:.1f}%)")
print(f"Free:  {fmt(free)}")
PYEOF
