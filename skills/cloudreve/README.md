# cloudreve

An [Agent Skills](https://agentskills.io)-compatible skill for managing files on a self-hosted [Cloudreve v4](https://cloudreve.org) cloud storage instance.

## Features

- Upload local files to Cloudreve (chunked, supports large files)
- Download files from Cloudreve to local
- List directory contents with filtering (by category, name, type, etc.)
- Delete files
- Check storage usage / quota
- JWT authentication with token refresh support
- Official API-compliant (see [docs](https://docs.cloudreve.org/zh/api/overview))

## Requirements

- A running Cloudreve v4 instance (Docker or binary)
- `CLOUDREVE_URL`, `CLOUDREVE_USER`, `CLOUDREVE_PASS` environment variables
- `curl` and `python3` in agent shell

## Installation

### OpenClaw

```bash
cp -r cloudreve ~/.agents/skills/
```

Then add to `openclaw.json`:

```json5
{
  skills: {
    entries: {
      "cloudreve": {
        enabled: true,
        env: {
          CLOUDREVE_URL: "https://cloudreve.example.com",
          CLOUDREVE_USER: "your-email@example.com",
          CLOUDREVE_PASS: "your-password"
        }
      }
    }
  }
}
```

Restart gateway after saving.

### Other Agents

Copy this directory to your agent's skills folder. The skill follows the [Agent Skills specification](https://agentskills.io/specification.md).

## Structure

```
cloudreve/
├── SKILL.md                      # Core instructions (agent loads this)
├── README.md                     # This file
├── LICENSE                       # MIT License
├── scripts/
│   ├── upload.sh                 # Upload file (chunked)
│   ├── download.sh               # Download file
│   ├── list.sh                   # List directory
│   ├── delete.sh                 # Delete file
│   └── storage.sh                # Show storage usage
└── references/
    └── api-reference.md          # Cloudreve v4 API docs
```

## Changelog

### v2.0.0 (2026-03-30)

- **Rewritten against official Cloudreve v4 API docs**
- Login: correct endpoint (`/api/v4/session/token`) and fields (`email`/`password`)
- File list: correct endpoint (`/api/v4/file?uri=`)
- Upload: now supports chunked upload for large files
- All JSON payloads use python3 construction (no shell injection)
- URL encoding for file URIs in query parameters
- Comprehensive error handling with official error codes
- SKILL.md follows Agent Skills spec: frontmatter, When to use/not use, workflow, gotchas
- Added file URI scheme documentation (query params for filtering)
- Added SSE file events endpoint reference
- Added official docs links throughout

### v1.0.0 (2026-03-28)

- Initial release (reverse-engineered API, not based on official docs)

## License

MIT
