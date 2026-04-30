# SearXNG Deployment Guide

## Quick start (Docker)

```bash
mkdir -p ~/searxng/searxng && cd ~/searxng

# Generate secret key
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### docker-compose.yml

```yaml
version: "3.8"
services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: unless-stopped
    ports:
      - "127.0.0.1:8888:8080"
    volumes:
      - ./searxng:/etc/searxng
    environment:
      - SEARXNG_BASE_URL=http://127.0.0.1:8888
      - SEARXNG_SECRET=<your-secret-key>
    cap_drop: [ALL]
    cap_add: [CHOWN, SETGID, SETUID]
    logging:
      driver: json-file
      options: { max-size: "10m", max-file: "3" }
    healthcheck:
      test: ["CMD", "wget", "--spider", "--quiet", "http://127.0.0.1:8080/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3
```

### settings.yml (China-optimized)

```yaml
use_default_settings: true

search:
  safe_search: 0
  autocomplete: "baidu"
  autocomplete_min: 2
  default_lang: "zh-CN"
  formats: [html, json]

server:
  bind_address: "0.0.0.0"
  port: 8080
  secret_key: "<your-secret-key>"
  limiter: true
  image_proxy: true
  method: "GET"
  base_url: "http://127.0.0.1:8888"

ui:
  default_theme: simple
  center_alignment: true

outgoing:
  request_timeout: 5.0
  max_request_timeout: 15.0
  pool_connections: 100
  pool_maxsize: 20
  enable_http2: true

engines:
  # --- Enable: China-accessible engines ---
  - name: baidu
    engine: baidu; shortcut: bd; baidu_category: general
    categories: [general]; timeout: 6.0; weight: 1.5; disabled: false
  - name: bing
    engine: bing; shortcut: bi
    categories: [general]; timeout: 6.0; weight: 1.2; disabled: false
  - name: 360search
    engine: 360search; shortcut: 360so
    categories: [general]; timeout: 10.0; weight: 1.0; disabled: false
  - name: baidu images
    engine: baidu; shortcut: bdi; baidu_category: images
    categories: [images]; timeout: 6.0; disabled: false
  - name: bing images
    engine: bing_images; shortcut: bii
    categories: [images]; timeout: 6.0; disabled: false
  - name: bing news
    engine: bing_news; shortcut: bin
    categories: [news]; timeout: 6.0; disabled: false
  - name: bing videos
    engine: bing_videos; shortcut: biv
    categories: [videos]; timeout: 6.0; disabled: false
  - name: bilibili
    engine: bilibili; shortcut: bil
    categories: [videos]; timeout: 6.0; disabled: false
  - name: baidu kaifa
    engine: baidu; shortcut: bdk; baidu_category: it
    categories: [it]; timeout: 6.0; disabled: false

  # --- Disable: GFW-blocked engines ---
  - name: google; disabled: true
  - name: duckduckgo; disabled: true
  - name: startpage; disabled: true
  - name: brave; disabled: true
  - name: wikipedia; disabled: true
  - name: qwant; disabled: true
  - name: yahoo; disabled: true
  - name: yep; disabled: true
  - name: mojeek; disabled: true
  - name: reddit; disabled: true
  - name: youtube; disabled: true
```

Deploy:

```bash
cd ~/searxng
docker compose up -d
```

## Verify

```bash
# Container health
docker ps --filter name=searxng

# API test
curl -s "http://127.0.0.1:8888/search?q=test&format=json" | python3 -c "
import sys, json; d = json.load(sys.stdin)
print(f'{len(d.get(\"results\",[]))} results from: {set(r.get(\"engine\") for r in d.get(\"results\",[]))}')
"

# Engine status
curl -s "http://127.0.0.1:8888/config" | python3 -c "
import sys, json
for e in sorted(json.load(sys.stdin).get('engines',[]), key=lambda x: x['name']):
    if e.get('enabled'): print(f'  ✅ {e[\"name\"]}')
"

# Response time
curl -o /dev/null -s -w "%{time_total}s\n" "http://127.0.0.1:8888/search?q=hello&format=json"
```

## Maintenance

```bash
# Logs
docker logs searxng --tail 100 -f

# Restart
docker restart searxng

# Update
docker compose pull && docker compose up -d

# Resource usage
docker stats searxng --no-stream
```

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Container restarting | `docker logs searxng` — check YAML syntax in settings.yml |
| No results | `curl -I https://www.baidu.com` — verify outbound network |
| Partial results | Normal — check `unresponsive_engines` in response |
| Connection refused | `ss -tlnp | grep 8888` — verify port binding |
| Slow response | Reduce `outgoing.request_timeout` or disable slow engines |
