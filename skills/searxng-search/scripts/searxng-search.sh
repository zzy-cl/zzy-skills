#!/usr/bin/env bash
# searxng-search.sh — SearXNG search helper script
# Usage: bash scripts/searxng-search.sh "query" [options]
#
# Options:
#   -c, --categories   Categories (default: general)
#   -l, --language     Language (default: zh-CN)
#   -e, --engines      Comma-separated engines
#   -t, --time-range   Time range: day|week|month|year
#   -p, --page         Page number (default: 1)
#   -n, --limit        Max results to show (default: 5)
#   -j, --json         Output raw JSON (no formatting)

set -euo pipefail

# --- Config ---
BASE_URL="${SEARXNG_BASE_URL:?Error: SEARXNG_BASE_URL not set}"

# --- Defaults ---
CATEGORIES="general"
LANGUAGE="zh-CN"
ENGINES=""
TIME_RANGE=""
PAGE=1
LIMIT=5
RAW_JSON=false
QUERY=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--categories) CATEGORIES="$2"; shift 2 ;;
    -l|--language)   LANGUAGE="$2"; shift 2 ;;
    -e|--engines)    ENGINES="$2"; shift 2 ;;
    -t|--time-range) TIME_RANGE="$2"; shift 2 ;;
    -p|--page)       PAGE="$2"; shift 2 ;;
    -n|--limit)      LIMIT="$2"; shift 2 ;;
    -j|--json)       RAW_JSON=true; shift ;;
    -h|--help)
      echo "Usage: $0 \"search query\" [options]"
      echo ""
      echo "Options:"
      echo "  -c, --categories   Categories (default: general)"
      echo "  -l, --language     Language (default: zh-CN)"
      echo "  -e, --engines      Engines (e.g., baidu,bing)"
      echo "  -t, --time-range   day|week|month|year"
      echo "  -p, --page         Page number (default: 1)"
      echo "  -n, --limit        Max results (default: 5)"
      echo "  -j, --json         Raw JSON output"
      exit 0
      ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"
      else
        QUERY="$QUERY $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo "Error: No search query provided" >&2
  echo "Usage: $0 \"search query\" [options]" >&2
  exit 1
fi

# --- Build URL ---
# URL-encode the query
ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY'''))")

URL="${BASE_URL}/search?q=${ENCODED_QUERY}&format=json&categories=${CATEGORIES}&language=${LANGUAGE}&pageno=${PAGE}"

[[ -n "$ENGINES" ]]    && URL="${URL}&engines=${ENGINES}"
[[ -n "$TIME_RANGE" ]] && URL="${URL}&time_range=${TIME_RANGE}"

# --- Execute ---
RESPONSE=$(curl -sf --connect-timeout 10 --max-time 20 "$URL" 2>&1) || {
  echo "Error: Failed to connect to SearXNG at ${BASE_URL}" >&2
  echo "Check that SearXNG is running: docker ps | grep searxng" >&2
  exit 1
}

# --- Output ---
if $RAW_JSON; then
  echo "$RESPONSE" | python3 -m json.tool
  exit 0
fi

echo "$RESPONSE" | python3 -c "
import sys, json, html, re

def strip_html(text):
    if not text:
        return ''
    clean = re.sub(r'<[^>]+>', '', text)
    return html.unescape(clean).strip()[:200]

try:
    d = json.load(sys.stdin)
except json.JSONDecodeError:
    print('Error: Invalid JSON response', file=sys.stderr)
    sys.exit(1)

query = d.get('query', '')
results = d.get('results', [])
suggestions = d.get('suggestions', [])
unresponsive = d.get('unresponsive_engines', [])

print(f'Search: {query}')
print(f'Results: {len(results)}')
if unresponsive:
    engines_down = [e[0] for e in unresponsive]
    print(f'Engines down: {\", \".join(engines_down)}')
print()

# Show direct answers
answers = d.get('answers', [])
if answers:
    print('📝 Direct answers:')
    for a in answers[:2]:
        print(f'  {a}')
    print()

# Show results
for i, r in enumerate(results[:$LIMIT], 1):
    engine = r.get('engine', '?')
    title = r.get('title', 'No title')
    url = r.get('url', '')
    content = strip_html(r.get('content', ''))
    engines = r.get('engines', [])
    score = r.get('score', 0)

    multi = ' ✓' if len(engines) > 1 else ''
    print(f'{i}. [{engine}{multi}] {title}')
    print(f'   {url}')
    if content:
        print(f'   {content}')
    print()

# Show suggestions
if suggestions:
    print(f'💡 Try also: {\" | \".join(suggestions[:3])}')
"
