# searxng-search

An [Agent Skills](https://agentskills.io)-compatible skill for internet search via a self-hosted [SearXNG](https://docs.searxng.org) instance.

## Features

- Meta-search across multiple engines (Baidu, Bing, 360 Search, Bilibili, etc.)
- China-optimized engine configuration (works behind GFW)
- Structured JSON API responses
- Helper script for shell-based searches
- Progressive disclosure: compact SKILL.md + detailed references

## How it works

The skill uses a two-tier search protocol:

```
User question → Agent decides to search
  ↓
Method 1: web_fetch (preferred)
  - Works with domain names and public IPs
  - Cleanest integration, no shell needed
  - If blocked (localhost/private IP) → ↓
  ↓
Method 2: exec + curl (fallback)
  - Works with any address including localhost
  - Requires shell access
  - If SearXNG is down → inform user
```

**Why not `web_search`?** The built-in `web_search` tool uses DuckDuckGo, which is blocked in mainland China. This skill provides a self-hosted alternative.

## Requirements

- A running SearXNG instance with JSON API enabled
- `SEARXNG_BASE_URL` environment variable
- For Method 1: domain or public IP (web_fetch compatible)
- For Method 2: `curl` and `python3` in agent shell

## Installation

### OpenClaw

```bash
openclaw skills install searxng-search
# or copy to workspace
cp -r searxng-search ~/.openclaw/workspace/skills/
```

Then add to `openclaw.json`:

```json5
{
  skills: {
    entries: {
      "searxng-search": {
        enabled: true,
        env: {
          SEARXNG_BASE_URL: "http://127.0.0.1:8888"
        }
      }
    }
  }
}
```

### Other Agents

Copy this directory to your agent's skills folder. The skill follows the [Agent Skills specification](https://agentskills.io/specification.md).

## Structure

```
searxng-search/
├── SKILL.md                      # Core instructions (agent loads this)
├── README.md                     # This file
├── scripts/
│   └── searxng-search.sh         # CLI helper script
├── references/
│   ├── api-reference.md          # Full API docs, response schema
│   └── deployment.md             # Docker deploy + China engine config
└── assets/                       # (empty, for future templates)
```

## License

MIT
