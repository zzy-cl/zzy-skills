---
name: searxng-search
description: |
  Search the internet via a self-hosted SearXNG instance. Use when the user asks questions requiring real-time information, news, fact-checking, product lookups, weather, or any knowledge beyond training data. Supports Baidu, Bing, 360 Search, Bilibili, and other engines. Works with both Claude Code and openClaw.
license: MIT
compatibility: Requires a running SearXNG instance with JSON API enabled. Works with Claude Code and openClaw. Agent must have either web_fetch access (domain/public IP) or exec/shell access (localhost fallback).
metadata:
  author: openclaw-community
  version: "1.2.0"
  openclaw:
    always: true
    emoji: "🔍"
    requires:
      env:
        - SEARXNG_BASE_URL
    primaryEnv: SEARXNG_BASE_URL
allowed-tools: web_fetch exec
---

# SearXNG Search

联网搜索 — 通过自部署的 SearXNG 元搜索引擎获取互联网实时信息。

## When to use

- User asks about current events, news, or time-sensitive information
- User asks about software versions, changelogs, or documentation
- User asks about prices, products, or comparisons
- User asks about people, companies, or locations you're unsure about
- Any question where training data might be outdated or incomplete

## When NOT to use

- Pure reasoning, math, or logic
- Well-established facts (e.g. "what is water")
- Questions about the current conversation context

## Setup

### Claude Code

Set `SEARXNG_BASE_URL` in `~/.claude/settings.json` (global) or `.claude/settings.json` (project):

```json
{
  "env": {
    "SEARXNG_BASE_URL": "https://searx.example.com"
  }
}
```

> **Note:** The `skills.entries` configuration shown in older documentation is **not supported** in Claude Code's settings.json schema. Simply setting the `SEARXNG_BASE_URL` environment variable is sufficient — the skill will automatically use it.

### openClaw

Set `SEARXNG_BASE_URL` in `openclaw.json`:

```json5
{
  skills: {
    entries: {
      "searxng-search": {
        enabled: true,
        env: {
          SEARXNG_BASE_URL: "https://searx.example.com"
        }
      }
    }
  }
}
```

> **Note:** For localhost/private IP deployments, both Claude Code and openClaw use `exec + curl` (Method 2) since `web_fetch` blocks private IPs. Public domains/IPs use `web_fetch`.

See [references/deployment.md](references/deployment.md) for SearXNG Docker setup.

## Search protocol

Searches MUST follow this priority order. Try each method in sequence; stop on first success.

### Method 1: web_fetch (preferred)

Use when `SEARXNG_BASE_URL` is a domain name or public IP.

```
web_fetch("{SEARXNG_BASE_URL}/search?q={query}&format=json&categories=general&language=zh-CN")
```

**When this fails:** web_fetch blocks localhost/private IPs. If you get an error mentioning "Blocked hostname", "private/internal IP", or connection refused — proceed to Method 2.

### Method 2: exec + curl (fallback)

Use when web_fetch cannot reach SearXNG (localhost, private IP, or network restriction).

```bash
curl -sf --connect-timeout 10 --max-time 20 \
  "{SEARXNG_BASE_URL}/search?q={query}&format=json&categories=general&language=zh-CN"
```

**When this fails:** SearXNG is down or unreachable. Inform the user and suggest checking: `docker ps --filter name=searxng`

### Parsing results

Both methods return the same JSON. Parse with:

```python
import json, re, html

def parse_response(raw):
    d = json.loads(raw)
    results = []
    for r in d.get("results", [])[:5]:
        content = re.sub(r"<[^>]+>", "", r.get("content", ""))
        content = html.unescape(content).strip()[:200]
        results.append({
            "title": r.get("title", ""),
            "url": r.get("url", ""),
            "content": content,
            "engine": r.get("engine", ""),
            "score": r.get("score", 0),
            "engines": r.get("engines", []),
        })
    return {
        "query": d.get("query", ""),
        "count": len(d.get("results", [])),
        "results": results,
        "answers": d.get("answers", []),
        "suggestions": d.get("suggestions", []),
    }
```

## Parameters

| Parameter | Default | Values |
|-----------|---------|--------|
| `categories` | `general` | `general`, `images`, `news`, `videos`, `science`, `it` |
| `language` | `auto` | `zh-CN`, `en-US`, `auto` |
| `pageno` | `1` | `1`-`5` |
| `time_range` | *(none)* | `day`, `week`, `month`, `year` |
| `engines` | *(all)* | `baidu`, `bing`, `360search`, `bilibili` |

Append to URL: `&categories=news&language=zh-CN&time_range=day`

## Result processing

1. Check `answers` first — direct extractions (definitions, calculations)
2. Check `infoboxes` — structured knowledge cards
3. Filter by `score` — ignore results with score < 1.0
4. Cross-validate — prefer results returned by multiple `engines`
5. If insufficient — try `suggestions` or adjust `language`/`categories`

For full response schema, see [references/api-reference.md](references/api-reference.md).

## Gotchas

- `content` may contain HTML tags — strip before presenting
- `unresponsive_engines` is normal — partial results are still valid
- Empty results ≠ failure — try `suggestions` or switch `language`
- For Chinese: `baidu` engine has best coverage. For English tech: use `bing`
- Minimum 1s between searches. On HTTP 429: wait 10s before retry
- Don't repeat the same query — change terms or parameters on retry

## Error handling

| Error | Cause | Action |
|-------|-------|--------|
| web_fetch "Blocked hostname" | localhost/private IP | Switch to Method 2 (exec+curl) |
| web_fetch timeout | Domain unreachable | Switch to Method 2 |
| curl connection refused | SearXNG not running | `docker start searxng` |
| HTTP 429 | Rate limited | Wait 10s, retry once |
| HTTP 5xx | SearXNG error | Check `docker logs searxng` |
| Empty results | No match | Broaden query or try `suggestions` |
| JSON parse error | Wrong response format | Ensure `format=json` in URL |
