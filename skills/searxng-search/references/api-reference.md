# SearXNG API Reference

## Endpoint

```
GET {SEARXNG_BASE_URL}/search
```

## Parameters

### Required

| Parameter | Type | Description |
|-----------|------|-------------|
| `q` | string | Search query (URL-encoded) |
| `format` | string | Must be `json` |

### Optional

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `categories` | string | `general` | Comma-separated category list |
| `engines` | string | *(all enabled)* | Comma-separated engine list |
| `language` | string | `auto` | BCP-47 language code |
| `pageno` | int | `1` | Page number (1-based) |
| `time_range` | string | *(none)* | `day`, `week`, `month`, `year` |
| `safesearch` | int | `0` | `0`=off, `1`=moderate, `2`=strict |

## Categories

| Category | Use case | Available engines |
|----------|----------|-------------------|
| `general` | Web pages | baidu, bing, 360search |
| `images` | Images | baidu images, bing images |
| `news` | News articles | bing news |
| `videos` | Videos | bing videos, bilibili |
| `science` | Academic papers | arxiv |
| `it` | Tech/developer | baidu kaifa |

Combine with comma: `categories=general,news`

## Engines (China-accessible)

| Engine | Weight | Best for |
|--------|--------|----------|
| `baidu` | 1.5 | Chinese content, Baike, Zhihu, CSDN |
| `bing` | 1.2 | International content, English docs |
| `360search` | 1.0 | Chinese web, general coverage |
| `bilibili` | 1.0 | Chinese video tutorials |
| `baidu images` | 1.0 | Chinese image search |
| `bing images` | 1.0 | International image search |
| `bing news` | 1.0 | News aggregation |
| `baidu kaifa` | 1.0 | Developer/IT content |

## Response schema

```json
{
  "query": "string",
  "number_of_results": 12345,
  "results": [
    {
      "title": "string",
      "url": "string",
      "content": "string (may contain HTML)",
      "engine": "string (primary source)",
      "engines": ["string (all sources)"],
      "score": 1.5,
      "category": "string",
      "publishedDate": "string | null",
      "img_src": "string | null",
      "thumbnail": "string | null"
    }
  ],
  "answers": ["string (direct answers)"],
  "infoboxes": [
    {
      "infobox": "string (title)",
      "content": "string",
      "attributes": [{"label": "string", "value": "string"}],
      "urls": [{"title": "string", "url": "string"}]
    }
  ],
  "suggestions": ["string (related queries)"],
  "corrections": ["string"],
  "unresponsive_engines": [["engine_name", "error"]]
}
```

## Query syntax

| Syntax | Example | Effect |
|--------|---------|--------|
| Exact phrase | `"machine learning"` | Must appear verbatim |
| Exclude term | `python -snake` | Remove results containing "snake" |
| Site filter | `site:github.com react` | Only search github.com |
| Title filter | `intitle:tutorial` | Keyword must be in title |
| File type | `filetype:pdf report` | Only PDF results |

## Result processing rules

1. **Check `answers` first** — these are direct extractions (definitions, calculations)
2. **Check `infoboxes`** — structured knowledge cards (Wikipedia/Wikidata style)
3. **Filter by `score`** — ignore results with score < 1.0
4. **Cross-validate** — prefer results returned by multiple `engines`
5. **Clean `content`** — strip HTML tags, trim whitespace
6. **If insufficient** — use `suggestions` for alternative queries, then try `pageno=2`

## Search strategy guide

| Goal | categories | engines | language | time_range |
|------|-----------|---------|----------|------------|
| Chinese general | `general` | `baidu,360search` | `zh-CN` | — |
| English tech docs | `general` | `bing` | `en-US` | — |
| Recent news | `news` | `bing` | `zh-CN` | `day` or `week` |
| Bilibili videos | `videos` | `bilibili` | `zh-CN` | — |
| Academic papers | `science` | *(default)* | `en-US` | `year` |
| Cross-language | `general` | *(default)* | `auto` | — |

For cross-language coverage, run two searches: one with `language=zh-CN`, another with `language=en-US`, then merge results.

## Retry policy

- **Connection error / 5xx**: retry up to 2 times, 3s interval
- **429 Too Many Requests**: wait 10s, then retry once
- **Empty results**: change query terms (don't repeat same query)
- **Minimum interval**: 1s between consecutive searches
